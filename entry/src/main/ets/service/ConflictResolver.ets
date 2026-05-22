import { ConflictItem, ConflictResolution, SyncItem, SyncState } from '../model/SyncModels';

export class ConflictResolver {
  detect(item: SyncItem, cloudVersion: string, watchVersion: string): ConflictItem | undefined {
    if (cloudVersion !== '' && watchVersion !== '' && cloudVersion !== watchVersion) {
      item.state = SyncState.CONFLICT;
      return {
        id: item.id,
        fileName: item.fileName,
        watchVersion: watchVersion,
        cloudVersion: cloudVersion,
        selectedResolution: ConflictResolution.MERGE
      };
    }
    return undefined;
  }

  resolve(conflict: ConflictItem, resolution: ConflictResolution): ConflictItem {
    conflict.selectedResolution = resolution;
    return conflict;
  }
}
