import { SyncDirection, SyncSnapshot } from '../model/SyncModels';
import { getSyncCoordinator } from '../service/SyncCoordinatorStore';

const coordinator = getSyncCoordinator();

@Component
export struct TransferPage {
  @State private snapshot: SyncSnapshot = coordinator.snapshot();
  @State private busy: boolean = false;
  pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.snapshot = coordinator.start();
  }

  private async runUploads(): Promise<void> {
    this.busy = true;
    this.snapshot = await coordinator.syncUploads();
    this.busy = false;
  }

  private async runDownloads(): Promise<void> {
    this.busy = true;
    this.snapshot = await coordinator.syncDownloads();
    this.busy = false;
  }

  private count(direction: SyncDirection): number {
    let total = 0;
    for (let i = 0; i < this.snapshot.queue.length; i++) {
      if (this.snapshot.queue[i].direction === direction) {
        total++;
      }
    }
    return total;
  }

  private openPage(url: string): void {
    this.pathStack.pushPathByName(url, null);
  }

  private goBack(): void {
    this.pathStack.pop();
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        Scroll() {
          Column({ space: 9 }) {
          this.header($r('app.string.transfer_page'))

          Text(this.snapshot.activeLabel)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .maxLines(2)

          this.transferCard($r('app.string.upload_files'), `${this.count(SyncDirection.PUSH)} queued`, $r('app.string.upload'), () => this.runUploads())
          this.transferCard($r('app.string.download_files'), `${this.count(SyncDirection.PULL)} queued`, $r('app.string.download'), () => this.runDownloads())

          Button($r('app.string.queue_page'))
            .width('100%')
            .height(30)
            .fontSize(11)
            .backgroundColor($r('app.color.card_bg'))
            .fontColor($r('app.color.text_primary'))
            .onClick(() => this.openPage('QueuePage'))
          }
          .width('100%')
          .padding(12)
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
    .onBackPressed((): boolean => {
      this.goBack();
      return true;
    })
    .onReady((context: NavDestinationContext): void => {
      this.pathStack = context.pathStack;
    })
  }

  @Builder
  private header(title: Resource) {
    Column({ space: 4 }) {
      Stack({ alignContent: Alignment.Center }) {
        Text('<')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
        .width(26)
        .height(26)
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(13)
        .onClick(() => this.goBack())
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private transferCard(title: Resource, detail: string, action: Resource, handler: () => void) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Text(detail)
        .fontSize(10)
        .fontColor($r('app.color.text_secondary'))

      Button(action)
        .width('100%')
        .height(30)
        .fontSize(11)
        .enabled(!this.busy)
        .backgroundColor($r('app.color.button_bg'))
        .fontColor($r('app.color.text_primary'))
        .onClick(handler)
    }
    .width('100%')
    .padding(10)
    .borderRadius(14)
    .backgroundColor($r('app.color.card_bg'))
  }
}
