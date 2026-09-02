import React from 'react';
import {AbsoluteFill, OffthreadVideo, Sequence, Series, useCurrentFrame, useVideoConfig} from 'remotion';
import type {CalculateMetadataFunction} from 'remotion';
import {Fundido} from '../componentes/Fundido';
import {MarcaDeAgua} from '../componentes/MarcaDeAgua';
import {Subtitulo} from '../componentes/Subtitulo';
import type {PropsSinSilencios, Segmento} from '../esquemas';
import {aPar, resolverFuente} from '../metadatos';

/**
 * Duración de cada tramo en frames. La usan tanto `calculateMetadata` como el
 * componente, así que tiene que ser una única función: si ambos redondearan
 * por su cuenta, la suma no cuadraría con la duración de la composición y el
 * último tramo saldría cortado.
 */
export const framesDeSegmentos = (segmentos: Segmento[], fps: number): number[] =>
  segmentos.map((s) => Math.max(1, Math.round((s.hasta - s.desde) * fps)));

export const calcularMetadatosSinSilencios: CalculateMetadataFunction<PropsSinSilencios> = ({
  props,
}) => {
  const frames = framesDeSegmentos(props.segmentos, props.fps);
  const total = frames.reduce((suma, f) => suma + f, 0);

  return {
    fps: props.fps,
    width: aPar(props.ancho),
    height: aPar(props.alto),
    durationInFrames: Math.max(1, total),
  };
};

/** Un tramo conservado del original. */
const Tramo: React.FC<{
  fuente: string;
  segmento: Segmento;
  duracion: number;
  indice: number;
  props: PropsSinSilencios;
}> = ({fuente, segmento, duracion, indice, props}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const desdeEnFrames = Math.round(segmento.desde * fps);
  const rampa = Math.max(1, Math.round(props.rampaAudio * fps));

  // El zoom alterna de sentido en cada tramo: el movimiento continuo disimula
  // el salto de imagen del corte, que en un plano fijo canta mucho.
  const avance = duracion > 1 ? frame / (duracion - 1) : 0;
  const escala = props.zoomSutil
    ? indice % 2 === 0
      ? 1 + props.intensidadZoom * avance
      : 1 + props.intensidadZoom * (1 - avance)
    : 1;

  return (
    <AbsoluteFill style={{overflow: 'hidden'}}>
      <AbsoluteFill style={{transform: `scale(${escala})`}}>
        <OffthreadVideo
          src={fuente}
          trimBefore={desdeEnFrames}
          trimAfter={desdeEnFrames + duracion}
          // Sin esta rampa, cada empalme corta la onda de audio a media
          // oscilación y se oye un clic.
          volume={(f) =>
            props.volumen *
            Math.min(1, (f + 1) / rampa, Math.max(0, duracion - f) / rampa)
          }
          style={{
            width: '100%',
            height: '100%',
            objectFit: props.ajuste === 'cubrir' ? 'cover' : 'contain',
          }}
        />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

export const SinSilencios: React.FC<PropsSinSilencios> = (props) => {
  const {fps} = useVideoConfig();
  const fuente = resolverFuente(props.fuente);
  const frames = framesDeSegmentos(props.segmentos, props.fps);

  return (
    <AbsoluteFill style={{backgroundColor: props.colorFondo}}>
      <Series>
        {props.segmentos.map((segmento, i) => (
          <Series.Sequence
            key={`${segmento.desde}-${i}`}
            durationInFrames={frames[i]}
            layout="none"
          >
            <Tramo
              fuente={fuente}
              segmento={segmento}
              duracion={frames[i]}
              indice={i}
              props={props}
            />
          </Series.Sequence>
        ))}
      </Series>

      {props.subtitulos.map((subtitulo, i) => (
        <Sequence
          key={`${subtitulo.desde}-${i}`}
          from={Math.round(subtitulo.desde * fps)}
          durationInFrames={Math.max(1, Math.round((subtitulo.hasta - subtitulo.desde) * fps))}
          name={`Subtítulo ${i + 1}`}
        >
          <Subtitulo texto={subtitulo.texto} />
        </Sequence>
      ))}

      <MarcaDeAgua {...props.marcaDeAgua} />

      <Fundido
        entradaEnFrames={Math.round(props.fundidoEntrada * fps)}
        salidaEnFrames={Math.round(props.fundidoSalida * fps)}
      />
    </AbsoluteFill>
  );
};
