import { SyncDirection, SyncItem, SyncSnapshot, SyncState } from '../model/SyncModels';
import { getSyncCoordinator } from '../service/SyncCoordinatorStore';

const coordinator = getSyncCoordinator();

@Component
export struct QueuePage {
  @State private snapshot: SyncSnapshot = coordinator.snapshot();
  pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.snapshot = coordinator.snapshot();
  }

  private goBack(): void {
    this.pathStack.pop();
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        Scroll() {
          Column({ space: 8 }) {
          this.header($r('app.string.queue_page'))

          Text(`${this.snapshot.queue.length} items waiting or completed`)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)

          if (this.snapshot.queue.length === 0) {
            Text($r('app.string.empty_queue'))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 18 })
          }

          ForEach(this.snapshot.queue, (item: SyncItem) => {
            Column({ space: 4 }) {
              Row() {
                Text(item.fileName)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(item.direction === SyncDirection.PUSH ? $r('app.string.upload') : $r('app.string.download'))
                  .fontSize(9)
                  .fontColor($r('app.color.accent'))
              }

              Row() {
                Text(item.state === SyncState.CONFLICT ? 'Conflict' : item.state)
                  .fontSize(10)
                  .fontColor(item.state === SyncState.ERROR ? $r('app.color.error') : $r('app.color.text_secondary'))
                  .layoutWeight(1)

                Text(`${item.progress}%`)
                  .fontSize(10)
                  .fontColor($r('app.color.text_secondary'))
              }

              Progress({ value: item.progress, total: 100, type: ProgressType.Linear })
                .width('100%')
                .height(4)
                .color(item.state === SyncState.ERROR ? $r('app.color.error') : $r('app.color.accent'))
                .backgroundColor($r('app.color.ring_bg'))
            }
            .width('100%')
            .padding(8)
            .borderRadius(14)
            .backgroundColor($r('app.color.card_bg'))
          }, (item: SyncItem): string => item.id)
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
}
