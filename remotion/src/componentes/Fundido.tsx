import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, useVideoConfig} from 'remotion';

/**
 * Capa negra que produce el fundido de entrada y de salida. Se pinta encima
 * de todo lo demás, así que también atenúa la marca de agua y los subtítulos.
 */
export const Fundido: React.FC<{entradaEnFrames: number; salidaEnFrames: number}> = ({
  entradaEnFrames,
  salidaEnFrames,
}) => {
  const frame = useCurrentFrame();
  const {durationInFrames} = useVideoConfig();

  if (entradaEnFrames <= 0 && salidaEnFrames <= 0) {
    return null;
  }

  const alEntrar =
    entradaEnFrames > 0
      ? interpolate(frame, [0, entradaEnFrames], [1, 0], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        })
      : 0;

  const alSalir =
    salidaEnFrames > 0
      ? interpolate(frame, [durationInFrames - salidaEnFrames, durationInFrames], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        })
      : 0;

  return (
    <AbsoluteFill
      style={{backgroundColor: 'black', opacity: Math.max(alEntrar, alSalir), pointerEvents: 'none'}}
    />
  );
};
