import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useSettings } from '../../store/settings';
import { useScanSession } from '../../store/scanSession';
import { getEngine, ENGINE_LIST, OcrError } from '../../engines';
import { callClaudeVision } from '../../engines/claudeEngine';
import { callGeminiVision } from '../../engines/geminiEngine';
import { decodeImage, decodeFromCamera } from '../../engines/barcode';
import { kvParser } from '../../services/kvParser';
import {
  lookupBarcode,
  productToKvMap,
  identifyFromImage,
} from '../../services/productLookup';
import type { InputType } from '../../services/historyRepo';
import { fileToDataUrl, preprocessForVision } from '../../ui/imageUtils';
import { CameraIcon, UploadIcon } from '../../ui/icons';
import type { OcrEngineId } from '../../store/settings';
import type { VisionFn } from '../../services/productLookup';

/**
 * Generative engines read a label straight into structured fields (one call via
 * identifyFromImage). Non-generative engines (Google Vision) return raw text for
 * the heuristic kvParser instead. Maps each generative engine to its vision call
 * and the source label shown on results.
 */
const GENERATIVE: Partial<
  Record<OcrEngineId, { vision: VisionFn; sourceLabel: string }>
> = {
  claude: { vision: callClaudeVision, sourceLabel: 'Claude Vision' },
  gemini: { vision: callGeminiVision, sourceLabel: 'Gemini' },
};

const ENGINE_CHIP: Record<OcrEngineId, string> = {
  claude: 'Claude',
  gemini: 'Gemini',
  google: 'Google',
};

export function CaptureScreen() {
  const navigate = useNavigate();
  const { ocrEngine, setOcrEngine, recordUsage } = useSettings();
  const setActive = useScanSession((s) => s.setActive);

  const [busy, setBusy] = useState(false);
  const [stage, setStage] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [needsKey, setNeedsKey] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [cameraOn, setCameraOn] = useState(false);
  const [liveCode, setLiveCode] = useState<string | null>(null);

  const fileInput = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const stopCamera = useRef<(() => void) | null>(null);

  const process = useCallback(
    async (imageDataUrl: string, inputType: InputType) => {
      setBusy(true);
      setError(null);
      setNeedsKey(false);
      try {
        const image = await preprocessForVision(imageDataUrl);

        setStage('Decoding barcode…');
        const barcode = await decodeImage(image);

        // Barcode → product lookup is shared by both engine paths.
        let productFields: Record<string, string> | null = null;
        if (barcode && !barcode.isQr) {
          setStage('Looking up product…');
          try {
            const info = await lookupBarcode(barcode.value);
            if (info) productFields = productToKvMap(info);
          } catch {
            // lookup is best-effort
          }
        }

        const engine = getEngine(ocrEngine);
        const generative = GENERATIVE[ocrEngine];
        let ocrText = '';
        let pairs;

        if (generative) {
          // Single structured call: a generative model (Claude/Gemini) reads the
          // label into demarcated fields directly, so there's no need for a
          // second manual lookup.
          setStage(`Reading label with ${ENGINE_CHIP[ocrEngine]}…`);
          let aiFields: Record<string, string> | null = null;
          try {
            const info = await identifyFromImage(
              image,
              generative.vision,
              generative.sourceLabel,
            );
            recordUsage(ocrEngine);
            if (info) aiFields = productToKvMap(info);
          } catch (e) {
            if (e instanceof OcrError && e.needsKey) {
              setNeedsKey(true);
            }
            throw e;
          }
          // Barcode-lookup product data wins on overlap; AI fills the rest.
          const combined = { ...(aiFields ?? {}), ...(productFields ?? {}) };
          pairs = kvParser.parse({ ocrText: '', barcode, productFields: combined });
          productFields = Object.keys(combined).length ? combined : productFields;
        } else {
          // Raw-text OCR (Google) → heuristic key/value parser.
          setStage('Reading text…');
          try {
            ocrText = await engine.recognizeText(image);
            recordUsage(ocrEngine);
          } catch (e) {
            if (e instanceof OcrError && e.needsKey) {
              setNeedsKey(true);
            }
            throw e;
          }
          pairs = kvParser.parse({ ocrText, barcode, productFields });
        }

        setActive({
          pairs,
          ocrText,
          barcodeValue: barcode?.value,
          barcodeFormat: barcode?.format,
          productName: productFields?.['Product Name'],
          productBrand: productFields?.['Brand'],
          imageDataUrl: image,
          inputType,
          engineLabel: engine.label,
        });
        navigate('/results');
      } catch (e) {
        setError(
          e instanceof Error ? e.message : 'Something went wrong. Try again.',
        );
      } finally {
        setBusy(false);
        setStage('');
      }
    },
    [ocrEngine, recordUsage, setActive, navigate],
  );

  const onFiles = useCallback(
    async (files: FileList | null) => {
      const file = files?.[0];
      if (!file) return;
      const dataUrl = await fileToDataUrl(file);
      await process(dataUrl, 'file');
    },
    [process],
  );

  // ── Camera lifecycle ──────────────────────────────────────────────────────
  useEffect(() => {
    if (!cameraOn || !videoRef.current) return;
    let cancelled = false;
    setLiveCode(null);
    decodeFromCamera(
      videoRef.current,
      (r) => !cancelled && setLiveCode(r.value),
      () => !cancelled && setError('Could not access the camera.'),
    ).then((stop) => {
      stopCamera.current = stop;
      if (cancelled) stop();
    });
    return () => {
      cancelled = true;
      stopCamera.current?.();
      stopCamera.current = null;
    };
  }, [cameraOn]);

  const captureFrame = useCallback(async () => {
    const video = videoRef.current;
    if (!video) return;
    const canvas = document.createElement('canvas');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext('2d')?.drawImage(video, 0, 0);
    const dataUrl = canvas.toDataURL('image/jpeg', 0.9);
    stopCamera.current?.();
    setCameraOn(false);
    await process(dataUrl, 'camera');
  }, [process]);

  return (
    <div className="space-y-5">
      {/* Engine quick-switch */}
      <div className="flex items-center gap-2 text-xs">
        <span className="text-slate-400">Engine:</span>
        <div className="flex gap-1.5">
          {ENGINE_LIST.map((e) => (
            <button
              key={e.id}
              onClick={() => setOcrEngine(e.id)}
              className={`rounded-full px-3 py-1 font-medium transition-colors ${
                ocrEngine === e.id
                  ? 'bg-brand-500 text-white'
                  : 'bg-white/5 text-slate-300 hover:bg-white/10'
              }`}
            >
              {ENGINE_CHIP[e.id]}
            </button>
          ))}
        </div>
      </div>

      {cameraOn ? (
        <div className="card overflow-hidden">
          <div className="relative aspect-[3/4] bg-black sm:aspect-video">
            <video
              ref={videoRef}
              className="h-full w-full object-cover"
              playsInline
              muted
            />
            <div className="pointer-events-none absolute inset-6 rounded-2xl border-2 border-white/60" />
            {liveCode && (
              <div className="absolute inset-x-3 bottom-3 truncate rounded-lg bg-black/70 px-3 py-2 text-center text-sm text-emerald-300">
                {liveCode}
              </div>
            )}
          </div>
          <div className="flex gap-2 p-3">
            <button className="btn-primary flex-1" onClick={captureFrame}>
              <CameraIcon className="h-5 w-5" /> Capture & Scan
            </button>
            <button
              className="btn-ghost"
              onClick={() => setCameraOn(false)}
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <div
          onDragOver={(e) => {
            e.preventDefault();
            setDragOver(true);
          }}
          onDragLeave={() => setDragOver(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDragOver(false);
            void onFiles(e.dataTransfer.files);
          }}
          className={`card flex flex-col items-center justify-center gap-3 p-10 text-center transition-colors ${
            dragOver ? 'border-brand-400 bg-brand-500/10' : ''
          }`}
        >
          <div className="grid h-14 w-14 place-items-center rounded-2xl bg-brand-500/15 text-brand-400">
            <UploadIcon className="h-7 w-7" />
          </div>
          <div>
            <p className="font-semibold">Drop an image, or choose one</p>
            <p className="text-xs text-slate-400">
              Product label, barcode or QR code · PNG / JPG
            </p>
          </div>
          <div className="mt-1 flex flex-wrap justify-center gap-2">
            <button
              className="btn-primary"
              onClick={() => fileInput.current?.click()}
              disabled={busy}
            >
              <UploadIcon className="h-5 w-5" /> Upload image
            </button>
            <button
              className="btn-ghost"
              onClick={() => {
                setError(null);
                setCameraOn(true);
              }}
              disabled={busy}
            >
              <CameraIcon className="h-5 w-5" /> Use camera
            </button>
          </div>
          <input
            ref={fileInput}
            type="file"
            accept="image/*"
            capture="environment"
            className="hidden"
            onChange={(e) => void onFiles(e.target.files)}
          />
        </div>
      )}

      {busy && (
        <div className="card flex items-center gap-3 p-4 text-sm">
          <span className="h-4 w-4 animate-spin rounded-full border-2 border-brand-400 border-t-transparent" />
          {stage || 'Working…'}
        </div>
      )}

      {error && (
        <div className="card border-red-500/30 bg-red-500/10 p-4 text-sm text-red-200">
          <p>{error}</p>
          {needsKey && (
            <button
              className="btn-ghost mt-2 py-1.5 text-sm"
              onClick={() => navigate('/settings')}
            >
              Open Settings
            </button>
          )}
        </div>
      )}

      <p className="text-center text-xs text-slate-500">
        Everything runs in your browser. Images and keys never leave your device
        except the direct call to your chosen OCR provider.
      </p>
    </div>
  );
}
