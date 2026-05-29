import json
import logging

try:
    import paho.mqtt.client as mqtt
except ImportError:
    mqtt = None

from core.exporters.base import Exporter

logger = logging.getLogger("datalogger.mqtt")


class MQTTExporter(Exporter):
    """Giảng khuôn (skeleton) cho việc đẩy dữ liệu lên MQTT Broker."""

    def __init__(self, host: str = "localhost", port: int = 1883, topic: str = "sensor/data"):
        self.host = host
        self.port = port
        self.topic = topic
        self.client = None
        if mqtt:
            self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

    def connect(self) -> bool:
        if not self.client:
            logger.error("paho-mqtt library not available.")
            return False

        try:
            self.client.connect(self.host, self.port, 60)
            self.client.loop_start()
            logger.info(f"Connected to MQTT broker at {self.host}:{self.port}")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to MQTT broker: {e}")
            return False

    def send(self, data: dict) -> bool:
        if not self.client:
            return False

        try:
            payload = json.dumps(data)
            self.client.publish(self.topic, payload)
            logger.debug(f"Data published to {self.topic}: {payload}")
            return True
        except Exception as e:
            logger.error(f"Failed to publish data: {e}")
            return False

    def disconnect(self) -> None:
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()
            logger.info("Disconnected from MQTT broker.")
