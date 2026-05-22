import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { APP_DOMAIN, LOG_TAG } from '../util/Constants';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(APP_DOMAIN, LOG_TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    AppStorage.setOrCreate('abilityContext', this.context);
    hilog.info(APP_DOMAIN, LOG_TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(APP_DOMAIN, LOG_TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(APP_DOMAIN, LOG_TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(APP_DOMAIN, LOG_TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(APP_DOMAIN, LOG_TAG, 'Succeeded in loading content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(APP_DOMAIN, LOG_TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(APP_DOMAIN, LOG_TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(APP_DOMAIN, LOG_TAG, 'Ability onBackground');
  }
}
