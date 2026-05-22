import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { cloudSync, fileIo, fileUri } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { APP_DOMAIN, LOG_TAG } from '../util/Constants';
import { SyncDirection, SyncItem, SyncState } from '../model/SyncModels';

type ProgressHandler = (progress: number, label: string) => void;
type ErrorHandler = (message: string) => void;

const CLOUD_SYNC_SYSCAP = 'SystemCapability.FileManagement.DistributedFileService.CloudSync.Core';

export class CloudSyncService {
  private isPaused: boolean = false;
  private progressHandler?: ProgressHandler;
  private errorHandler?: ErrorHandler;
  private fileSync: cloudSync.FileSync = new cloudSync.FileSync();
  private fileCache: cloudSync.CloudFileCache = new cloudSync.CloudFileCache();
  private syncProgressCallback = (progress: cloudSync.SyncProgress): void => {
    this.handleSyncProgress(progress);
  };
  private downloadProgressCallback = (progress: cloudSync.DownloadProgress): void => {
    this.handleDownloadProgress(progress);
  };
  private currentDownloadUri: string = '';
  private initialized: boolean = false;
  private emulatorFallbackActive: boolean = false;

  bindProgress(handler: ProgressHandler): void {
    this.progressHandler = handler;
  }

  bindError(handler: ErrorHandler): void {
    this.errorHandler = handler;
  }

  registerProgressCallback(): void {
    this.ensureInitialized();
    hilog.info(APP_DOMAIN, LOG_TAG, 'CoreFileKit cloud sync callbacks registered');
  }

  private ensureInitialized(): void {
    if (!this.initialized) {
      if (!canIUse(CLOUD_SYNC_SYSCAP)) {
        this.handleCloudServiceUnavailable({ code: 13600001, message: 'CloudSync.Core syscap unavailable' } as BusinessError);
        this.initialized = true;
        return;
      }
      try {
        this.fileSync.on('progress', this.syncProgressCallback);
        this.fileCache.on('progress', this.downloadProgressCallback);
      } catch (err) {
        if (!this.handleCloudServiceUnavailable(err as BusinessError)) {
          throw new Error(this.toCoreFileErrorMessage(err as BusinessError));
        }
      }
      this.initialized = true;
    }
  }

  pause(): void {
    this.isPaused = true;
    this.stopActiveWork();
    this.progressHandler?.(0, 'Paused');
  }

  resume(): void {
    this.isPaused = false;
    if (!this.isCloudSyncAvailable()) {
      this.progressHandler?.(100, 'Emulator fallback: cloud sync unavailable');
      return;
    }
    this.fileSync.start().catch((err: Error) => {
      this.handleCoreFileError(err, 'Cloud sync resume failed');
    });
    this.progressHandler?.(0, 'Resumed');
  }

  async sync(item: SyncItem, context: common.UIAbilityContext): Promise<SyncItem> {
    if (this.isPaused) {
      item.state = SyncState.PAUSED;
      return item;
    }

    item.state = SyncState.SYNCING;
    item.progress = 5;
    this.progressHandler?.(item.progress, `${item.direction} ${item.fileName}`);

    try {
      this.ensureInitialized();
      if (item.direction === SyncDirection.PUSH) {
        await this.pushWithCloudSync(item, context);
      } else {
        await this.pullWithCloudSync(item, context);
      }
      item.state = SyncState.DONE;
      item.progress = 100;
      item.updatedAt = Date.now();
      this.progressHandler?.(100, `${item.direction} complete`);
    } catch (err) {
      item.state = SyncState.ERROR;
      item.errorMessage = this.toCoreFileErrorMessage(err as BusinessError);
      this.reportError(item.errorMessage);
    }

    return item;
  }

  private async pushWithCloudSync(item: SyncItem, context: common.UIAbilityContext): Promise<void> {
    hilog.info(APP_DOMAIN, LOG_TAG, 'Uploading from %{public}s to %{public}s', item.localPath, item.cloudPath);
    const cloudPath = this.toCloudPath(context, item.cloudPath);
    if (!this.ensureParentDir(cloudPath)) {
      throw new Error('Unable to prepare cloud sync directory');
    }
    if (!await this.copyFileSafely(item.localPath, cloudPath, 'Cloud upload staging failed')) {
      throw new Error('Cloud upload staging failed');
    }
    await this.runFileSync(item, 'Uploading to cloud');
  }

  private async pullWithCloudSync(item: SyncItem, context: common.UIAbilityContext): Promise<void> {
    hilog.info(APP_DOMAIN, LOG_TAG, 'Downloading from %{public}s to %{public}s', item.cloudPath, item.localPath);
    const cloudPath = this.toCloudPath(context, item.cloudPath);
    const cloudUri = fileUri.getUriFromPath(cloudPath);
    this.currentDownloadUri = cloudUri;
    try {
      await this.fileCache.start(cloudUri);
    } catch (err) {
      if (!this.handleCloudServiceUnavailable(err as BusinessError)) {
        throw new Error(this.toCoreFileErrorMessage(err as BusinessError));
      }
    }
    if (this.pathExists(cloudPath)) {
      if (!await this.copyFileSafely(cloudPath, item.localPath, 'Cloud download cache copy failed')) {
        throw new Error('Cloud download cache copy failed');
      }
    }
    this.currentDownloadUri = '';
  }

  private async runFileSync(item: SyncItem, label: string): Promise<void> {
    try {
      item.progress = 60;
      this.progressHandler?.(item.progress, label);
      if (!this.isCloudSyncAvailable()) {
        return;
      }
      try {
        await this.fileSync.start();
      } catch (err) {
        if (!this.handleCloudServiceUnavailable(err as BusinessError)) {
          throw new Error(this.toCoreFileErrorMessage(err as BusinessError));
        }
      }
    } finally {
      hilog.info(APP_DOMAIN, LOG_TAG, 'CoreFileKit cloud sync step finished');
    }
  }

  private stopActiveWork(): void {
    if (!this.isCloudSyncAvailable()) {
      return;
    }
    this.fileSync.stop().catch((err: Error) => {
      this.handleCoreFileError(err, 'Cloud sync stop failed');
    });
    if (this.currentDownloadUri !== '') {
      this.fileCache.stop(this.currentDownloadUri).catch((err: Error) => {
        this.handleCoreFileError(err, 'Cloud file download stop failed');
      });
    }
  }

  private handleCloudServiceUnavailable(err: BusinessError): boolean {
    if (err.code !== 13600001) {
      return false;
    }

    this.emulatorFallbackActive = true;
    this.progressHandler?.(100, 'Emulator fallback: cloud sync unavailable');
    hilog.warn(APP_DOMAIN, LOG_TAG, 'CoreFileKit cloud sync service unavailable: %{public}s', this.toCoreFileErrorMessage(err));
    return true;
  }

  private isCloudSyncAvailable(): boolean {
    if (this.emulatorFallbackActive) {
      return false;
    }
    if (!canIUse(CLOUD_SYNC_SYSCAP)) {
      this.handleCloudServiceUnavailable({ code: 13600001, message: 'CloudSync.Core syscap unavailable' } as BusinessError);
      return false;
    }
    return true;
  }

  private handleCoreFileError(err: Error, prefix: string): void {
    const businessError = err as BusinessError;
    if (this.handleCloudServiceUnavailable(businessError)) {
      return;
    }
    this.reportError(`${prefix}: ${this.toCoreFileErrorMessage(businessError)}`);
  }

  private toCoreFileErrorMessage(err: BusinessError): string {
    if (err.code === 13600001) {
      return 'CoreFileKit cloud sync service is unavailable. This usually happens on emulators or devices without CloudSync.Core service support.';
    }
    if (err.message) {
      return `${err.message} (${err.code})`;
    }
    return JSON.stringify(err);
  }

  private handleSyncProgress(progress: cloudSync.SyncProgress): void {
    if (progress.error !== cloudSync.ErrorType.NO_ERROR) {
      this.reportError(`Cloud sync error ${progress.error}`);
      return;
    }
    if (progress.state === cloudSync.SyncState.COMPLETED) {
      this.progressHandler?.(100, 'Cloud sync complete');
    } else if (progress.state === cloudSync.SyncState.UPLOADING) {
      this.progressHandler?.(75, 'Uploading to cloud');
    } else if (progress.state === cloudSync.SyncState.DOWNLOADING) {
      this.progressHandler?.(75, 'Downloading from cloud');
    } else if (progress.state === cloudSync.SyncState.STOPPED) {
      this.progressHandler?.(0, 'Cloud sync stopped');
    }
  }

  private handleDownloadProgress(progress: cloudSync.DownloadProgress): void {
    if (progress.error !== cloudSync.DownloadErrorType.NO_ERROR) {
      this.reportError(`Cloud file download error ${progress.error}`);
      return;
    }
    if (progress.size > 0) {
      this.progressHandler?.(Math.min(Math.floor((progress.processed / progress.size) * 100), 99), 'Downloading from cloud');
    } else if (progress.state === cloudSync.State.COMPLETED) {
      this.progressHandler?.(100, 'Download complete');
    }
  }

  private toCloudPath(context: common.UIAbilityContext, cloudPath: string): string {
    if (cloudPath.startsWith('/')) {
      return cloudPath;
    }
    return `${context.filesDir}/cloud/${cloudPath}`;
  }

  private pathExists(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch (err) {
      this.reportError(`Unable to check path: ${this.toCoreFileErrorMessage(err as BusinessError)}`);
      return false;
    }
  }

  private ensureParentDir(path: string): boolean {
    const lastSlash = path.lastIndexOf('/');
    if (lastSlash <= 0) {
      return true;
    }
    const dir = path.substring(0, lastSlash);
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
      return true;
    } catch (err) {
      this.reportError(`Unable to create directory: ${this.toCoreFileErrorMessage(err as BusinessError)}`);
      return false;
    }
  }

  private async copyFileSafely(source: string, destination: string, message: string): Promise<boolean> {
    try {
      await fileIo.copyFile(source, destination, 0);
      return true;
    } catch (err) {
      this.reportError(`${message}: ${this.toCoreFileErrorMessage(err as BusinessError)}`);
      return false;
    }
  }

  private reportError(message: string): void {
    if (this.emulatorFallbackActive && message.indexOf('13600001') >= 0) {
      return;
    }
    hilog.error(APP_DOMAIN, LOG_TAG, '%{public}s', message);
    this.errorHandler?.(message);
  }
}
