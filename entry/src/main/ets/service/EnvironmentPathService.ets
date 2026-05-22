import { common } from '@kit.AbilityKit';
import { Environment } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { APP_DOMAIN, LOG_TAG } from '../util/Constants';
import { StoragePaths } from '../model/SyncModels';

const ENVIRONMENT_FOLDER_SYSCAP = 'SystemCapability.FileManagement.File.Environment.FolderObtain';

export class EnvironmentPathService {
  resolvePaths(context: common.UIAbilityContext): StoragePaths {
    const downloadDir: string = this.resolveDownloadDir(context);

    hilog.info(APP_DOMAIN, LOG_TAG, 'Resolved downloadDir=%{public}s', downloadDir);
    return {
      downloadDir: downloadDir
    };
  }

  private resolveDownloadDir(context: common.UIAbilityContext): string {
    if (!canIUse(ENVIRONMENT_FOLDER_SYSCAP)) {
      hilog.warn(APP_DOMAIN, LOG_TAG, 'User download directory syscap unavailable; using application cache directory');
      return context.cacheDir;
    }
    try {
      return Environment.getUserDownloadDir();
    } catch (err) {
      hilog.warn(APP_DOMAIN, LOG_TAG, 'User download directory unavailable on this device: %{public}s', JSON.stringify(err));
      return context.cacheDir;
    }
  }

}
