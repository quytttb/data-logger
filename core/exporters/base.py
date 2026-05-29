from abc import ABC, abstractmethod
import logging

logger = logging.getLogger("datalogger.exporters")


class Exporter(ABC):
    """Abstract Base Class for Data Exporters (Cloud, HTTP, MQTT, etc.)."""

    @abstractmethod
    def connect(self) -> bool:
        """Establish connection to the remote endpoint. Returns True if successful."""
        pass

    @abstractmethod
    def send(self, data: dict) -> bool:
        """Send data payload. Returns True if successfully sent."""
        pass

    @abstractmethod
    def disconnect(self) -> None:
        """Close connection gracefully."""
        pass
