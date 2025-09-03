import json

from pathlib import Path
from spread_auth.core.config import Settings

Path('/config/schema.json').write_text(
    json.dumps(Settings.model_json_schema(), indent=2)
)
