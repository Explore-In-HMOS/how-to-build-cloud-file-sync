import { SyncDirection, SyncItem, SyncState } from '../model/SyncModels';

export class OfflineQueueService {
  private queue: SyncItem[] = [];

  enqueue(fileName: string, localPath: string, cloudPath: string, direction: SyncDirection): SyncItem {
    const item: SyncItem = {
      id: `${Date.now()}-${this.queue.length}`,
      fileName: fileName,
      localPath: localPath,
      cloudPath: cloudPath,
      direction: direction,
      state: SyncState.QUEUED,
      progress: 0,
      updatedAt: Date.now()
    };
    this.queue.push(item);
    return item;
  }

  list(): SyncItem[] {
    return this.queue;
  }

  update(item: SyncItem): void {
    const index = this.queue.findIndex((queued) => queued.id === item.id);
    if (index >= 0) {
      this.queue[index] = item;
    }
  }

  clearDone(): void {
    this.queue = this.queue.filter((item) => item.state !== SyncState.DONE);
  }
}
