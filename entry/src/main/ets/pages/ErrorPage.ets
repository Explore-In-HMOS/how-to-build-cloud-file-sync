import { SyncSnapshot } from '../model/SyncModels';
import { getSyncCoordinator } from '../service/SyncCoordinatorStore';

const coordinator = getSyncCoordinator();

@Component
export struct ErrorPage {
  @State private snapshot: SyncSnapshot = coordinator.snapshot();
  pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.snapshot = coordinator.snapshot();
  }

  private recover(): void {
    this.snapshot = coordinator.recover();
  }

  private clearErrors(): void {
    this.snapshot = coordinator.clearErrors();
  }

  private goBack(): void {
    this.pathStack.pop();
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        Scroll() {
          Column({ space: 8 }) {
          this.header($r('app.string.error_page'))

          if (this.snapshot.errorLog.length === 0) {
            Text($r('app.string.no_errors'))
              .fontSize(12)
              .fontColor($r('app.color.success'))
              .margin({ top: 20 })
          }

          ForEach(this.snapshot.errorLog, (message: string) => {
            Text(message)
              .width('100%')
              .fontSize(10)
              .fontColor($r('app.color.error'))
              .maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding(8)
              .borderRadius(14)
              .backgroundColor($r('app.color.card_bg'))
          }, (message: string): string => message)

          Row({ space: 6 }) {
            Button($r('app.string.retry'))
              .height(30)
              .layoutWeight(1)
              .fontSize(11)
              .backgroundColor($r('app.color.button_bg'))
              .fontColor($r('app.color.text_primary'))
              .onClick(() => this.recover())

            Button($r('app.string.clear_errors'))
              .height(30)
              .layoutWeight(1)
              .fontSize(11)
              .backgroundColor($r('app.color.card_bg'))
              .fontColor($r('app.color.text_primary'))
              .onClick(() => this.clearErrors())
          }
          .width('100%')
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
