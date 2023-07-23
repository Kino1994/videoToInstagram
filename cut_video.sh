#!/bin/bash

# Verificar si se proporcionó al menos un argumento (nombre del video)
if [ $# -lt 1 ]; then
    echo "Uso: $0 <video_entrada> [<inicio> <final>]"
    echo "Ejemplo: $0 video.mp4 00:17 02:08"
    exit 1
fi

# Obtener los argumentos
input_video="$1"
start_time="$2"
end_time="$3"

# Función para convertir el tiempo en formato HH:mm:ss o mm:ss a segundos
time_to_seconds() {
  local time_str="$1"
  local h=0
  local m=0
  local s=0

  # Leer las partes del tiempo en caso de que estén presentes
  if [[ "$time_str" == *:*:* ]]; then
    h=$(echo "$time_str" | cut -d: -f1)
    m=$(echo "$time_str" | cut -d: -f2)
    s=$(echo "$time_str" | cut -d: -f3)
  elif [[ "$time_str" == *:* ]]; then
    m=$(echo "$time_str" | cut -d: -f1)
    s=$(echo "$time_str" | cut -d: -f2)
  fi

  echo $((10#$h * 3600 + 10#$m * 60 + 10#$s))
}

# Obtener la duración total del video en segundos
total_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_video")

# Verificar si se proporcionaron los argumentos de tiempo de inicio y finalización
if [ -z "$start_time" ] && [ -z "$end_time" ]; then
    # Si no se proporcionaron, definir el tiempo de inicio como 0 y el tiempo de finalización como la duración total del video
    start_seconds=0
    end_seconds=$total_duration
else
    # Obtener los tiempos de inicio y finalización en segundos
    start_seconds=$(time_to_seconds "$start_time")
    end_seconds=$(time_to_seconds "$end_time")
fi

# Validar que los tiempos de inicio y finalización estén dentro de los límites del video
if [ $start_seconds -ge $end_seconds ] || [ $start_seconds -ge $total_duration ] || [ $end_seconds -gt $total_duration ]; then
    echo "Error: Los tiempos de inicio y finalización son inválidos o están fuera del rango del video."
    exit 1
fi

# Duración objetivo de cada segmento en segundos (15 segundos)
segment_duration=15

# Resolución deseada para los segmentos con relación de aspecto 9:16 (1080x1920)
target_resolution="1920x1080"

# Calcular la cantidad de segmentos completos y la duración del último segmento
segments=$(awk "BEGIN { print int(($end_seconds - $start_seconds) / $segment_duration) }")
last_segment_duration=$(awk "BEGIN { print ($end_seconds - $start_seconds) - ($segments * $segment_duration) }")

# Nombre base para los segmentos
output_base="segmento"

# Cortar los segmentos completos
for ((i=1; i<=$segments; i++))
do
  start_time_segment=$(awk "BEGIN { print $start_seconds + (($i - 1) * $segment_duration) }")
  target_file="${output_base}${i}_1920x1080.mp4"
  output_file="${output_base}${i}.mp4"
  ffmpeg -ss "$start_time_segment" -i "$input_video" -t "$segment_duration" -vf "scale=$target_resolution" -c:v libx264 -c:a copy "$target_file"
  ffmpeg -y -i "$target_file" -vf "transpose=1" -c:v libx264 -c:a copy "$output_file"
  rm $target_file
done

# Cortar el último segmento si es necesario
if (( $(echo "$last_segment_duration > 0" | bc -l) ))
then
  start_time_last_segment=$(awk "BEGIN { print $end_seconds - $last_segment_duration }")
  target_file="${output_base}${i}_1920x1080.mp4"
  output_file="${output_base}${i}.mp4"
  ffmpeg -ss "$start_time_last_segment" -i "$input_video" -t "$last_segment_duration" -vf "scale=$target_resolution" -c:v libx264 -c:a copy "$target_file"
  ffmpeg -y -i "$target_file" -vf "transpose=1" -c:v libx264 -c:a copy "$output_file"
  ffmpeg -y -i "$target_file" -vf "transpose=1" -c:v libx264 -c:a copy "$output_file"
  rm $target_file
fi
