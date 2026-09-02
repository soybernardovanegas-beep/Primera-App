import React from 'react';
import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import type {IntroProps} from '../esquemas';

/** Portada con título y subtítulo que se muestra antes del video. */
export const Intro: React.FC<IntroProps> = ({titulo, subtitulo, colorFondo, colorTexto}) => {
  const frame = useCurrentFrame();
  const {fps, height, durationInFrames} = useVideoConfig();

  const entrada = spring({frame, fps, config: {damping: 200}});
  const salida = interpolate(
    frame,
    [durationInFrames - fps * 0.4, durationInFrames],
    [1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );

  return (
    <AbsoluteFill
      style={{
        backgroundColor: colorFondo,
        justifyContent: 'center',
        alignItems: 'center',
        opacity: salida,
        gap: height * 0.03,
        padding: height * 0.1,
      }}
    >
      <h1
        style={{
          margin: 0,
          color: colorTexto,
          fontSize: height * 0.11,
          fontFamily: 'Arial, Helvetica, sans-serif',
          fontWeight: 800,
          textAlign: 'center',
          transform: `scale(${interpolate(entrada, [0, 1], [0.9, 1])})`,
          opacity: entrada,
        }}
      >
        {titulo}
      </h1>
      {subtitulo ? (
        <h2
          style={{
            margin: 0,
            color: colorTexto,
            opacity: entrada * 0.75,
            fontSize: height * 0.045,
            fontFamily: 'Arial, Helvetica, sans-serif',
            fontWeight: 400,
            textAlign: 'center',
          }}
        >
          {subtitulo}
        </h2>
      ) : null}
    </AbsoluteFill>
  );
};
