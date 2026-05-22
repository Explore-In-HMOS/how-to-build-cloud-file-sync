import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { APP_DOMAIN, LOG_TAG } from '../util/Constants';

export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    hilog.info(APP_DOMAIN, LOG_TAG, 'onBackup');
  }

  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    hilog.info(APP_DOMAIN, LOG_TAG, 'onRestore %{public}s', JSON.stringify(bundleVersion));
  }
}
