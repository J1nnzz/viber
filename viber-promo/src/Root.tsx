import { Composition } from "remotion";
import { ViberPromo } from "./ViberPromo";

// (3+5+4+4+10+6+8+7)*30 - 7*12 = 1326 frames ≈ 44.2s
const TOTAL_FRAMES = 1326;
const FPS = 30;

export const Root: React.FC = () => (
  <Composition
    id="ViberPromo"
    component={ViberPromo}
    durationInFrames={TOTAL_FRAMES}
    fps={FPS}
    width={1920}
    height={1080}
  />
);
