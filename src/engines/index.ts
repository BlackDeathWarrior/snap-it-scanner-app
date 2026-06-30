import type { OcrEngine } from './ocrEngine';
import type { OcrEngineId } from '../store/settings';
import { claudeEngine } from './claudeEngine';
import { googleVisionEngine } from './googleVisionEngine';
import { geminiEngine } from './geminiEngine';

export const ENGINES: Record<OcrEngineId, OcrEngine> = {
  claude: claudeEngine,
  google: googleVisionEngine,
  gemini: geminiEngine,
};

// Google Cloud Vision is disabled for now (slow backend round-trip; the BYO-key
// Claude/Gemini engines replace it). Re-enable by adding googleVisionEngine back
// to this list. It stays in ENGINES so persisted state / types stay valid.
export const ENGINE_LIST: OcrEngine[] = [claudeEngine, geminiEngine];

export function getEngine(id: OcrEngineId): OcrEngine {
  return ENGINES[id];
}

export { OcrError } from './ocrEngine';
export type { OcrEngine } from './ocrEngine';
