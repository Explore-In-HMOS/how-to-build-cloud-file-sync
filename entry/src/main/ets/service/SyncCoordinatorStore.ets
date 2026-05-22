import { SyncCoordinator } from './SyncCoordinator';

const coordinator = new SyncCoordinator();

export function getSyncCoordinator(): SyncCoordinator {
  return coordinator;
}
