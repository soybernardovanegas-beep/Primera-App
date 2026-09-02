import React from 'react';
import {AbsoluteFill, OffthreadVideo, Series, useVideoConfig} from 'remotion';
import type {CalculateMetadataFunction} from 'remotion';
import {Fundido} from '../componentes/Fundido';
import type {PropsUnirClips} from '../esquemas';
import {aPar, leerMetadatos, resolverFuente} from '../metadatos';

/** Duración de cada clip en segundos, resolviendo los `hasta` que vengan en null. */
const duracionesDeClips = async (clips: PropsUnirClips['clips']): Promise<number[]> => {
  return Promise.all(
    clips.map(async (clip) => {
      const hasta =
        clip.hasta ?? (await leerMetadatos(resolverFuente(clip.fuente))).duracionEnSegundos;
      return Math.max(0, hasta - clip.desde);
    }),
  );
};

export const calcularMetadatosUnion: CalculateMetadataFunction<PropsUnirClips> = async ({props}) => {
  const duraciones = await duracionesDeClips(props.clips);
  const total = duraciones.reduce((suma, d) => suma + d, 0);

  return {
    fps: props.fps,
    width: aPar(props.ancho),
    height: aPar(props.alto),
    durationInFrames: Math.max(1, Math.round(total * props.fps)),
    // Guardamos los `hasta` ya resueltos para no volver a leer los archivos.
    props: {
      ...props,
      clips: props.clips.map((clip, i) => ({...clip, hasta: clip.desde + duraciones[i]})),
    },
  };
};

export const UnirClips: React.FC<PropsUnirClips> = ({
  clips,
  ajuste,
  colorFondo,
  fundidoEntreClips,
}) => {
  const {fps} = useVideoConfig();
  const framesFundido = Math.round(fundidoEntreClips * fps);

  return (
    <AbsoluteFill style={{backgroundColor: colorFondo}}>
      <Series>
        {clips.map((clip, i) => {
          const desdeEnFrames = Math.round(clip.desde * fps);
          const hastaEnFrames = Math.round((clip.hasta ?? clip.desde) * fps);
          const duracion = Math.max(1, hastaEnFrames - desdeEnFrames);

          return (
            <Series.Sequence
              key={`${clip.fuente}-${i}`}
              durationInFrames={duracion}
              // El primer clip no lleva fundido de entrada ni el último de salida:
              // esos los controla el fundido general de la composición.
              layout="none"
            >
              <AbsoluteFill>
                <OffthreadVideo
                  src={resolverFuente(clip.fuente)}
                  trimBefore={desdeEnFrames}
                  trimAfter={Math.max(desdeEnFrames + 1, hastaEnFrames)}
                  muted={clip.silenciar}
                  style={{
                    width: '100%',
                    height: '100%',
                    objectFit: ajuste === 'cubrir' ? 'cover' : 'contain',
                  }}
                />
                <Fundido
                  entradaEnFrames={i === 0 ? 0 : framesFundido}
                  salidaEnFrames={i === clips.length - 1 ? 0 : framesFundido}
                />
              </AbsoluteFill>
            </Series.Sequence>
          );
        })}
      </Series>
    </AbsoluteFill>
  );
};
