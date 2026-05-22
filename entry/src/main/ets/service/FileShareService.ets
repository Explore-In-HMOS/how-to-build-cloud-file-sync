import { fileShare } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { APP_DOMAIN, LOG_TAG } from '../util/Constants';

const FILE_SHARE_SYSCAP = 'SystemCapability.FileManagement.AppFileService.FolderAuthorization';
const READ_MODE = 1;

export class FileShareService {
  async grantToPhone(uri: string): Promise<void> {
    if (!canIUse(FILE_SHARE_SYSCAP)) {
      hilog.warn(APP_DOMAIN, LOG_TAG, 'File sharing syscap unavailable; skipping permission grant for %{public}s', uri);
      return;
    }
    const policy: fileShare.PolicyInfo = {
      uri: uri,
      operationMode: READ_MODE
    };
    const policies: Array<fileShare.PolicyInfo> = [policy];

    try {
      const states = await fileShare.checkPersistentPermission(policies);
      if (states.length === 0 || !states[0]) {
        await fileShare.persistPermission(policies);
      }
      await fileShare.activatePermission(policies);
    } catch (err) {
      hilog.warn(APP_DOMAIN, LOG_TAG, 'File sharing permission grant failed: %{public}s', JSON.stringify(err));
      return;
    }
    hilog.info(APP_DOMAIN, LOG_TAG, 'Granted read access for %{public}s', uri);
  }
}
