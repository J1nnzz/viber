import { AbsoluteFill, Audio, staticFile, interpolate, Sequence } from "remotion";
import { TransitionSeries, linearTiming, springTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { slide } from "@remotion/transitions/slide";
import { wipe } from "@remotion/transitions/wipe";
import { IntroScene } from "./scenes/IntroScene";
import { HookScene } from "./scenes/HookScene";
import { LogoScene } from "./scenes/LogoScene";
import { LoginScene } from "./scenes/LoginScene";
import { SalaScene } from "./scenes/SalaScene";
import { SyncScene } from "./scenes/SyncScene";
import { ExplorarScene } from "./scenes/ExplorarScene";
import { ClosingScene } from "./scenes/ClosingScene";

const FPS = 30;
const T = 12; // frames de transición

// Duraciones brutas de cada escena (en frames)
const INTRO_DUR    = FPS * 3;   // 90f
const HOOK_DUR     = FPS * 5;   // 150f
const LOGO_DUR     = FPS * 4;   // 120f
const LOGIN_DUR    = FPS * 4;   // 120f
const SALA_DUR     = FPS * 10;  // 300f
const SYNC_DUR     = FPS * 6;   // 180f
const EXPLORAR_DUR = FPS * 8;   // 240f
const CLOSING_DUR  = FPS * 7;   // 210f
// 7 transiciones × 12f = 84f de overlap — total neto: 1326f ≈ 44.2s

// ── Offset: la intro ocupa INTRO_DUR - T frames antes del gancho ─────────────
const OFFSET = INTRO_DUR - T; // 78

// ── Frames de inicio globales de cada escena en la composición ──────────────
const HOOK_START     = OFFSET;                                // 78
const LOGO_START     = HOOK_START    + HOOK_DUR     - T;     // 216
const LOGIN_START    = LOGO_START    + LOGO_DUR     - T;     // 324
const SALA_START     = LOGIN_START   + LOGIN_DUR    - T;     // 432
const SYNC_START     = SALA_START    + SALA_DUR     - T;     // 720
const EXPLORAR_START = SYNC_START    + SYNC_DUR     - T;     // 888
const CLOSING_START  = EXPLORAR_START + EXPLORAR_DUR - T;   // 1116

// ── Narración ElevenLabs ─────────────────────────────────────────────────────
// duckTo: volumen de Drake mientras habla ese clip
//   clips 1-3, 6-7 -> 0.55 (música audible, escenas tranquilas)
//   clips 4-5      -> 0.20 (narrador bien claro en Sala y Sync)
const NARRATION: Array<{ from: number; frames: number; src: string; duckTo: number }> = [
  { from: 98,                  frames: 168, src: "clip-1.mp3", duckTo: 0.55 },
  { from: 228,                 frames: 142, src: "clip-2.mp3", duckTo: 0.55 },
  { from: 348,                 frames: 124, src: "clip-3.mp3", duckTo: 0.55 },
  { from: 618,                 frames: 210, src: "clip-4.mp3", duckTo: 0.20 }, // Sala
  { from: SYNC_START  + 62,   frames: 165, src: "clip-5.mp3", duckTo: 0.20 }, // Sync
  { from: EXPLORAR_START + 69, frames: 157, src: "clip-6.mp3", duckTo: 0.50 },
  { from: CLOSING_START  + 20, frames: 143, src: "clip-7.mp3", duckTo: 0.45 },
];

// ── Volumen dinámico de Drake con ducking por clip ───────────────────────────
const BASE_VOL = 0.75;
const FADE_F   = 18;

const musicVolume = (f: number): number => {
  // Sin música durante la escena de intro (créditos)
  if (f < OFFSET) return 0;

  const base = interpolate(f, [OFFSET, OFFSET + 3], [0, BASE_VOL], { extrapolateRight: "clamp" });

  let reduction = 0;
  for (const clip of NARRATION) {
    const end = clip.from + clip.frames;
    const d = interpolate(
      f,
      [clip.from - FADE_F, clip.from, end, end + FADE_F],
      [0, 1, 1, 0],
      { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
    );
    reduction = Math.max(reduction, d * (BASE_VOL - clip.duckTo));
  }

  return Math.max(0, base - reduction);
};

export const ViberPromo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: "#07070F" }}>
      {/* ── MÚSICA ── Passionfruit desde 1:00, silencio durante la intro */}
      <Audio
        src={staticFile("passionfruit.mp3")}
        startFrom={Math.floor(60 * FPS)}
        volume={musicVolume}
      />
      {/* ── NARRACIÓN ── 7 clips de ElevenLabs, uno por escena */}
      {NARRATION.map((clip, i) => (
        <Sequence key={`narr-${i}`} from={clip.from}>
          <Audio src={staticFile(clip.src)} volume={1} />
        </Sequence>
      ))}
      {/* ── ESCENAS ── */}
      <TransitionSeries>

        {/* 0. INTRO — créditos del proyecto, sin sonido */}
        <TransitionSeries.Sequence durationInFrames={INTRO_DUR}>
          <IntroScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: T })}
        />

        {/* 1. GANCHO */}
        <TransitionSeries.Sequence durationInFrames={HOOK_DUR}>
          <HookScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: T })}
        />

        {/* 2. LOGO */}
        <TransitionSeries.Sequence durationInFrames={LOGO_DUR}>
          <LogoScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={slide({ direction: "from-right" })}
          timing={springTiming({ config: { damping: 200 }, durationInFrames: T })}
        />

        {/* 3. LOGIN */}
        <TransitionSeries.Sequence durationInFrames={LOGIN_DUR}>
          <LoginScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={wipe({ direction: "from-left" })}
          timing={linearTiming({ durationInFrames: T })}
        />

        {/* 4. SALA CON DRAKE */}
        <TransitionSeries.Sequence durationInFrames={SALA_DUR}>
          <SalaScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: T })}
        />

        {/* 5. DOS DISPOSITIVOS SINCRONIZADOS */}
        <TransitionSeries.Sequence durationInFrames={SYNC_DUR}>
          <SyncScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={slide({ direction: "from-bottom" })}
          timing={springTiming({ config: { damping: 200 }, durationInFrames: T })}
        />

        {/* 6. EXPLORAR */}
        <TransitionSeries.Sequence durationInFrames={EXPLORAR_DUR}>
          <ExplorarScene />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={fade()}
          timing={linearTiming({ durationInFrames: T })}
        />

        {/* 7. CIERRE EMOCIONAL */}
        <TransitionSeries.Sequence durationInFrames={CLOSING_DUR}>
          <ClosingScene />
        </TransitionSeries.Sequence>

      </TransitionSeries>
    </AbsoluteFill>
  );
};
