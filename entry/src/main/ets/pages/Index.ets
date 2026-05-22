import { SyncSnapshot } from '../model/SyncModels';
import { getSyncCoordinator } from '../service/SyncCoordinatorStore';
import { ErrorPage } from './ErrorPage';
import { QueuePage } from './QueuePage';
import { StartPage } from './StartPage';
import { TransferPage } from './TransferPage';

const coordinator = getSyncCoordinator();

@Entry
@Component
struct Index {
  @State private snapshot: SyncSnapshot = coordinator.snapshot();
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.snapshot = coordinator.snapshot();
  }

  private openPage(url: string): void {
    this.pathStack.pushPathByName(url, null);
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Center }) {
        Scroll() {
          Column({ space: 10 }) {
            Text($r('app.string.app_title'))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .margin({ top: 12 })

            Text($r('app.string.landing_summary'))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .maxLines(3)

            Column({ space: 4 }) {
              Text(this.snapshot.activeLabel)
                .fontSize(12)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(`${this.snapshot.queue.length} queued  ${this.snapshot.errorLog.length} errors`)
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding(10)
            .borderRadius(16)
            .backgroundColor($r('app.color.card_bg'))

            this.navButton($r('app.string.start_page'), 'StartPage')
            this.navButton($r('app.string.transfer_page'), 'TransferPage')
            this.navButton($r('app.string.queue_page'), 'QueuePage')
            this.navButton($r('app.string.error_page'), 'ErrorPage')
          }
          .width('100%')
          .padding(14)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor($r('app.color.bg_primary'))
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_primary'))
    }
    .hideTitleBar(true)
    .hideToolBar(true)
    .navDestination(this.pageBuilder)
  }

  @Builder
  private pageBuilder(name: string, _param: Object) {
    if (name === 'StartPage') {
      StartPage({ pathStack: this.pathStack })
    } else if (name === 'TransferPage') {
      TransferPage({ pathStack: this.pathStack })
    } else if (name === 'QueuePage') {
      QueuePage({ pathStack: this.pathStack })
    } else if (name === 'ErrorPage') {
      ErrorPage({ pathStack: this.pathStack })
    }
  }

  @Builder
  private navButton(label: Resource, url: string) {
    Button(label)
      .width('100%')
      .height(32)
      .fontSize(11)
      .backgroundColor($r('app.color.button_bg'))
      .fontColor($r('app.color.text_primary'))
      .onClick(() => this.openPage(url))
  }
}
