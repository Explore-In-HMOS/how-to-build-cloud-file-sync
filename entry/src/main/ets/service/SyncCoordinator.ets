import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { DEFAULT_CLOUD_FILE, DEFAULT_DOWNLOAD_FILE, DEFAULT_WATCH_FILE } from '../util/Constants';
import { CloudSyncService } from './CloudSyncService';
import { ConflictResolver } from './ConflictResolver';
import { EnvironmentPathService } from './EnvironmentPathService';
import { FileShareService } from './FileShareService';
import { OfflineQueueService } from './OfflineQueueService';
import {
  ConflictItem,
  ConflictResolution,
  SyncDirection,
  SyncItem,
  SyncSnapshot,
  SyncState
} from '../model/SyncModels';

export class SyncCoordinator {
  private env = new EnvironmentPathService();
  private queue = new OfflineQueueService();
  private cloud = new CloudSyncService();
  private share = new FileShareService();
  private resolver = new ConflictResolver();
  private conflicts: ConflictItem[] = [];
  private isOnline: boolean = true;
  private isPaused: boolean = false;
  private activeLabel: string = 'Ready';
  private progress: number = 0;
  private lastError: string = '';
  private errorLog: string[] = [];
  private resolvedConflictIds: string[] = [];
  private started: boolean = false;

  constructor() {
    this.cloud.bindProgress((progress: number, label: string): void => {
      this.progress = progress;
      this.activeLabel = label;
    });
    this.cloud.bindError((message: string): void => {
      this.recordError(message);
      this.activeLabel = 'Recovery needed';
    });
  }

  start(): SyncSnapshot {
    this.cloud.registerProgressCallback();
    if (this.started) {
      return this.snapshot();
    }

    const context = AppStorage.get<common.UIAbilityContext>('abilityContext') as common.UIAbilityContext;
    if (!context) {
      this.recordError('Ability context unavailable');
      this.activeLabel = 'Sync unavailable';
      return this.snapshot();
    }

    const paths = this.env.resolvePaths(context);
    const localPath = `${paths.downloadDir}/${DEFAULT_WATCH_FILE}`;
    this.ensureSeedFile(localPath);
    this.queue.enqueue(DEFAULT_WATCH_FILE, localPath, DEFAULT_CLOUD_FILE, SyncDirection.PUSH);
    this.queue.enqueue(DEFAULT_DOWNLOAD_FILE, `${paths.downloadDir}/${DEFAULT_DOWNLOAD_FILE}`, DEFAULT_CLOUD_FILE,
      SyncDirection.PULL);
    this.activeLabel = 'Queued cloud files';
    this.started = true;
    return this.snapshot();
  }

  setOnline(isOnline: boolean): SyncSnapshot {
    this.isOnline = isOnline;
    this.activeLabel = isOnline ? 'Back online' : 'Offline queueing';
    return this.snapshot();
  }

  async batchSync(): Promise<SyncSnapshot> {
    await this.syncQueuedItems();
    return this.snapshot();
  }

  async syncUploads(): Promise<SyncSnapshot> {
    await this.syncQueuedItems(SyncDirection.PUSH);
    return this.snapshot();
  }

  async syncDownloads(): Promise<SyncSnapshot> {
    await this.syncQueuedItems(SyncDirection.PULL);
    return this.snapshot();
  }

  private async syncQueuedItems(direction?: SyncDirection): Promise<void> {
    const context = AppStorage.get<common.UIAbilityContext>('abilityContext') as common.UIAbilityContext;
    if (!context) {
      this.recordError('Ability context unavailable');
      this.activeLabel = 'Sync unavailable';
      return;
    }

    if (!this.isOnline) {
      this.activeLabel = 'Waiting for network';
      return;
    }

    if (this.isPaused) {
      this.activeLabel = 'Sync paused';
      return;
    }

    const items = this.queue.list();
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (direction !== undefined && item.direction !== direction) {
        continue;
      }
      const conflict = this.resolvedConflictIds.includes(item.id) ? undefined :
        this.resolver.detect(item, 'cloud-v2', i === 0 ? 'watch-v1' : 'cloud-v2');
      if (conflict) {
        this.conflicts.push(conflict);
        this.queue.update(item);
        this.activeLabel = 'Conflict found';
        continue;
      }

      const synced = await this.cloud.sync(item, context);
      this.queue.update(synced);
    }
  }

  pause(): SyncSnapshot {
    this.isPaused = true;
    this.cloud.pause();
    return this.snapshot();
  }

  resume(): SyncSnapshot {
    this.isPaused = false;
    this.cloud.resume();
    return this.snapshot();
  }

  recover(): SyncSnapshot {
    this.lastError = '';
    this.activeLabel = 'Retry ready';
    const items = this.queue.list();
    for (let i = 0; i < items.length; i++) {
      if (items[i].state === SyncState.ERROR) {
        items[i].state = SyncState.QUEUED;
        items[i].progress = 0;
        this.queue.update(items[i]);
      }
    }
    return this.snapshot();
  }

  clearErrors(): SyncSnapshot {
    this.lastError = '';
    this.errorLog = [];
    this.activeLabel = 'Errors cleared';
    return this.snapshot();
  }

  resolveFirstConflict(resolution: ConflictResolution): SyncSnapshot {
    if (this.conflicts.length === 0) {
      return this.snapshot();
    }

    const conflict = this.resolver.resolve(this.conflicts[0], resolution);
    const item = this.queue.list().find((queued) => queued.id === conflict.id);
    if (item) {
      item.state = SyncState.QUEUED;
      item.progress = 0;
      this.queue.update(item);
      this.resolvedConflictIds.push(item.id);
    }
    this.conflicts.shift();
    this.activeLabel = `Resolved: ${resolution}`;
    return this.snapshot();
  }

  async grantShare(context: common.UIAbilityContext): Promise<SyncSnapshot> {
    const paths = this.env.resolvePaths(context);
    try {
      await this.share.grantToPhone(fileUri.getUriFromPath(`${paths.downloadDir}/${DEFAULT_WATCH_FILE}`));
      this.activeLabel = 'URI granted';
    } catch (err) {
      this.recordError(`Unable to grant URI: ${JSON.stringify(err)}`);
      this.activeLabel = 'Share failed';
    }
    return this.snapshot();
  }

  private ensureSeedFile(localPath: string): void {
    try {
      const file = fileIo.openSync(localPath,
        fileIo.OpenMode.CREATE |
        fileIo.OpenMode.TRUNC |
        fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, JSON.stringify({ title: 'Watch note', updatedAt: Date.now() }));
      fileIo.closeSync(file);
    } catch (err) {
      this.recordError(`Unable to prepare upload file: ${JSON.stringify(err)}`);
      this.activeLabel = 'File setup failed';
    }
  }

  private recordError(message: string): void {
    this.lastError = message;
    this.errorLog.unshift(`${new Date().toLocaleTimeString()} ${message}`);
  }

  snapshot(): SyncSnapshot {
    return {
      isOnline: this.isOnline,
      isPaused: this.isPaused,
      activeLabel: this.activeLabel,
      progress: this.progress,
      queue: this.queue.list(),
      conflicts: this.conflicts,
      lastError: this.lastError,
      errorLog: this.errorLog
    };
  }
}
