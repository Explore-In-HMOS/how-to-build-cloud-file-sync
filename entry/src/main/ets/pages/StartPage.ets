import { common } from '@kit.AbilityKit';
import { ConflictResolution, SyncItem, SyncSnapshot, SyncState } from '../model/SyncModels';
import { getSyncCoordinator } from '../service/SyncCoordinatorStore';

const coordinator = getSyncCoordinator();

@Component
export struct StartPage {
  @State private snapshot: SyncSnapshot = coordinator.snapshot();
  @State private busy: boolean = false;
  pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    this.snapshot = coordinator.start();
  }

  private async runBatchSync(): Promise<void> {
    this.busy = true;
    this.snapshot = await coordinator.batchSync();
    this.busy = false;
  }

  private toggleOnline(): void {
    this.snapshot = coordinator.setOnline(!this.snapshot.isOnline);
  }

  private togglePause(): void {
    this.snapshot = this.snapshot.isPaused ? coordinator.resume() : coordinator.pause();
  }

  private async shareWithPhone(): Promise<void> {
    const context = AppStorage.get<common.UIAbilityContext>('abilityContext') as common.UIAbilityContext;
    if (context) {
      this.snapshot = await coordinator.grantShare(context);
    }
  }

  private resolveConflict(resolution: ConflictResolution): void {
    this.snapshot = coordinator.resolveFirstConflict(resolution);
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
          Column({ space: 8 }) {
          this.header($r('app.string.start_page'))

          Text(this.snapshot.activeLabel)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Stack() {
            Progress({ value: this.snapshot.progress, total: 100, type: ProgressType.Ring })
              .width(104)
              .height(104)
              .color(this.snapshot.isPaused ? $r('app.color.warning') : $r('app.color.accent'))
              .backgroundColor($r('app.color.ring_bg'))

            Column() {
              Text(`${this.snapshot.progress}%`)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text(this.snapshot.isOnline ? $r('app.string.online') : $r('app.string.offline'))
                .fontSize(10)
                .fontColor(this.snapshot.isOnline ? $r('app.color.success') : $r('app.color.warning'))
            }
          }

          Row({ space: 6 }) {
            this.actionButton($r('app.string.sync_now'), () => this.runBatchSync())
            this.actionButton(this.snapshot.isPaused ? $r('app.string.resume') : $r('app.string.pause'), () => this.togglePause())
          }
          .width('100%')

          Row({ space: 6 }) {
            this.actionButton(this.snapshot.isOnline ? $r('app.string.go_offline') : $r('app.string.go_online'), () => this.toggleOnline())
            this.actionButton($r('app.string.share'), () => this.shareWithPhone())
          }
          .width('100%')

          this.queueSummary()

          if (this.snapshot.conflicts.length > 0) {
            this.conflictPanel()
          }

          if (this.snapshot.lastError !== '') {
            Button($r('app.string.error_page'))
              .height(28)
              .fontSize(11)
              .backgroundColor($r('app.color.error'))
                .onClick(() => this.openPage('ErrorPage'))
          }
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
  private actionButton(label: Resource, handler: () => void) {
    Button(label)
      .height(30)
      .layoutWeight(1)
      .fontSize(11)
      .enabled(!this.busy)
      .backgroundColor($r('app.color.button_bg'))
      .fontColor($r('app.color.text_primary'))
      .onClick(handler)
  }

  @Builder
  private queueSummary() {
    Column({ space: 4 }) {
      Text(`${this.snapshot.queue.length} queued`)
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))

      ForEach(this.snapshot.queue, (item: SyncItem) => {
        Row() {
          Text(item.fileName)
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.state === SyncState.CONFLICT ? 'Conflict' : item.state)
            .fontSize(10)
            .fontColor(item.state === SyncState.ERROR ? $r('app.color.error') : $r('app.color.text_primary'))
        }
      }, (item: SyncItem): string => item.id)
    }
    .width('100%')
    .padding(8)
    .borderRadius(14)
    .backgroundColor($r('app.color.card_bg'))
  }

  @Builder
  private conflictPanel() {
    Column({ space: 6 }) {
      Text($r('app.string.conflict_title'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.warning'))

      Text(this.snapshot.conflicts[0].fileName)
        .fontSize(10)
        .fontColor($r('app.color.text_secondary'))

      Row({ space: 4 }) {
        this.smallConflictButton($r('app.string.keep_watch'), ConflictResolution.KEEP_WATCH)
        this.smallConflictButton($r('app.string.keep_cloud'), ConflictResolution.KEEP_CLOUD)
        this.smallConflictButton($r('app.string.merge'), ConflictResolution.MERGE)
      }
    }
    .width('100%')
    .padding(8)
    .borderRadius(14)
    .backgroundColor($r('app.color.conflict_bg'))
  }

  @Builder
  private smallConflictButton(label: Resource, resolution: ConflictResolution) {
    Button(label)
      .height(26)
      .layoutWeight(1)
      .fontSize(9)
      .backgroundColor($r('app.color.button_bg'))
      .onClick(() => this.resolveConflict(resolution))
  }
}
