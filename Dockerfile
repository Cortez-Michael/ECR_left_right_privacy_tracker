# thor (arm64, gpu) dockerfile for pedestrian-direction-tracker
# Uses L4T (Linux for Tegra) base image for Jetson hardware compatibility
FROM nvcr.io/nvidia/l4t-pytorch:r36.2.0-pth2.2-py3

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    MPLBACKEND=Agg \
    QT_QPA_PLATFORM=offscreen

# FORCE PyTorch to use NVIDIA's custom UCX library instead of the broken system defaults
ENV LD_LIBRARY_PATH=/opt/hpcx/ucx/lib:$LD_LIBRARY_PATH

# system packages (with QEMU arm64 file-lock bypass for systemd)
RUN apt-get update && \
    (apt-get install -y --no-install-recommends \
    git cmake pkg-config build-essential gfortran \
    libgeos-dev sqlite3 \
    libjpeg-dev libpng-dev libtiff-dev \
    libopenblas0-pthread liblapack-dev libhdf5-dev libomp-dev \
    gstreamer1.0-tools gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-libav || \
    (sed -i -e '/systemd-sysusers/s/\.conf$/.conf || true/' /var/lib/dpkg/info/*.postinst && apt-get install -y -f)) \
 && rm -rf /var/lib/apt/lists/*

# Purge any system-level GUI OpenCV that NVIDIA baked into the OS
RUN apt-get update && apt-get remove -y python3-opencv || true && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .

RUN python3 -m pip install --no-cache-dir -r requirements.txt

RUN python3 -m pip install --no-cache-dir onnxslim onnxruntime
RUN python3 -m pip install --no-cache-dir --no-deps ultralytics

# ------------------------------------
# Add YOLOv8 weights for offline use
# ------------------------------------
RUN mkdir -p /app/models

# Add the BoT-SORT ReID model to prevent runtime download crashes
ADD https://github.com/ultralytics/assets/releases/download/v8.4.0/yolo26s-reid.onnx /app/models/yolo26s-reid.onnx

ADD https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8n.pt /app/models/yolov8n.pt
ADD https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8s.pt /app/models/yolov8s.pt
ADD https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8m.pt /app/models/yolov8m.pt
ADD https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8l.pt /app/models/yolov8l.pt
ADD https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8x.pt /app/models/yolov8x.pt

# yolov8-face weights for the Offline_Tracking.py privacy blur pass
ADD https://github.com/YapaLab/yolo-face/releases/download/1.0.0/yolov8n-person.pt /app/models/yolov8n-face.pt

COPY . .

# -------------------------------------------------------------
# ABSOLUTE LAST STEP: Force headless OpenCV so ultralytics cannot overwrite it
# -------------------------------------------------------------
RUN python3 -m pip uninstall -y opencv-python opencv-contrib-python || true \
 && python3 -m pip install --no-cache-dir --force-reinstall "opencv-python-headless>=4.5.0"

# default entrypoint: main.py (left/right counter).
ENTRYPOINT ["python3", "main.py"]
