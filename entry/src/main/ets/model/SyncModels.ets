export enum SyncDirection {
  PUSH = 'Push',
  PULL = 'Pull'
}

export enum SyncState {
  QUEUED = 'Queued',
  SYNCING = 'Syncing',
  PAUSED = 'Paused',
  CONFLICT = 'Conflict',
  ERROR = 'Error',
  DONE = 'Done'
}

export enum ConflictResolution {
  KEEP_WATCH = 'Keep watch',
  KEEP_CLOUD = 'Keep cloud',
  MERGE = 'Merge'
}

export interface SyncItem {
  id: string;
  fileName: string;
  localPath: string;
  cloudPath: string;
  direction: SyncDirection;
  state: SyncState;
  progress: number;
  updatedAt: number;
  errorMessage?: string;
}

export interface ConflictItem {
  id: string;
  fileName: string;
  watchVersion: string;
  cloudVersion: string;
  selectedResolution: ConflictResolution;
}

export interface StoragePaths {
  downloadDir: string;
}

export interface SyncSnapshot {
  isOnline: boolean;
  isPaused: boolean;
  activeLabel: string;
  progress: number;
  queue: SyncItem[];
  conflicts: ConflictItem[];
  lastError: string;
  errorLog: string[];
}
