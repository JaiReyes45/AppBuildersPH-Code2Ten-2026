"""Offline artifact smoke check. Requires numpy, onnxruntime and tokenizers.
Run from the repository root: python tool/validate_model.py
No runtime downloads or gallery access.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
import onnxruntime as ort
from tokenizers import Tokenizer

root = Path('assets/models')
manifest = json.loads((root / 'manifest.json').read_text())
for name, info in manifest['files'].items():
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == info['sha256'], name

tokenizer = Tokenizer.from_file(str(root / 'tokenizer.json'))
tokenizer.no_padding()
tokenizer.no_truncation()
session = ort.InferenceSession(str(root / 'minilm.onnx'), providers=['CPUExecutionProvider'])
fixtures = json.loads(Path('test/fixtures/minilm_reference.json').read_text())
for fixture in fixtures:
    encoded = tokenizer.encode(fixture['text'])
    assert encoded.ids == fixture['ids']
    inputs = {name: np.array([values], dtype=np.int64) for name, values in {
        'input_ids': encoded.ids, 'attention_mask': encoded.attention_mask,
        'token_type_ids': encoded.type_ids}.items()}
    output = session.run(None, inputs)[0]
    vector = output.mean(axis=1)[0]
    vector /= np.linalg.norm(vector)
    assert vector.shape == (384,) and np.isfinite(vector).all()
    assert np.dot(vector, fixture['vector']) > .999
print(f'Validated hashes, tokenizer IDs and inference for {len(fixtures)} synthetic fixtures.')
