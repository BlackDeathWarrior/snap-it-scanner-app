import type { OcrEngine } from './ocrEngine';
import type { OcrEngineId } from '../store/settings';
import { claudeEngine } from './claudeEngine';
import { googleVisionEngine } from './googleVisionEngine';

export const ENGINES: Record<OcrEngineId, OcrEngine> = {
  claude: claudeEngine,
  google: googleVisionEngine,
};

export const ENGINE_LIST: OcrEngine[] = [claudeEngine, googleVisionEngine];

export function getEngine(id: OcrEngineId): OcrEngine {
  return ENGINES[id];
}

export { OcrError } from './ocrEngine';
export type { OcrEngine } from './ocrEngine';
