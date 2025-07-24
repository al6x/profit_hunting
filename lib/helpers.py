import os
import os, pickle
from datetime import datetime
import numpy as np
import os
import os, pickle
from datetime import datetime
import re

def cached(key, get):
  path = f"./tmp/cache/{key}-{datetime.now():%Y-%m-%d}.pkl"
  if os.path.exists(path):
    print(f"  {key} loaded from cache")
    with open(path, 'rb') as f: return pickle.load(f)
  print(f"  {key} calculating")
  result = get()
  os.makedirs(os.path.dirname(path), exist_ok=True)
  with open(path, 'wb') as f: pickle.dump(result, f)
  return result

report_config = None

def configure_report(report_path, asset_path, asset_url_path):
  global report_config

  class ReportConfig:
    def __init__(self):
      self.report_path = report_path
      self.asset_path = asset_path
      self.asset_url_path = asset_url_path
      self.first_call = True

  report_config = ReportConfig()

def report(msg, print_=True, clear=True):
  if not report_config:
    raise ValueError("no report config")

  def turn2space_indent_into4(text):
    return text.replace('\n  ', '\n    ')

  def replace_h1_with_h3(text):
    return re.sub(r'(^|\n)# ', r'\1### ', text)

  def dedent(s):
    lines = s.strip('\n').splitlines()
    non_empty = [line for line in lines if line.strip()]
    if not non_empty:
      return ''
    min_indent = min(len(line) - len(line.lstrip(' ')) for line in non_empty)
    return '\n'.join(line[min_indent:] if len(line) >= min_indent else line for line in lines)

  if report_config.first_call:
    report_config.first_call = False
    if clear and os.path.exists(report_config.report_path):
      os.remove(report_config.report_path)

  msg = dedent(msg)

  # if print_:
  #   indented_msg = "\n".join("  " + line for line in msg.splitlines())
  #   print(indented_msg + "\n")

  # os.makedirs(os.path.dirname(report_path), exist_ok=True)
  with open(report_config.report_path, "a") as f:
    msg = turn2space_indent_into4(replace_h1_with_h3(msg)).rstrip()
    f.write(msg + "\n\n")

def save_asset(obj, name, clear=True):
  if not report_config:
    raise ValueError("no report config")

  def safe_name(s):
    s = re.sub(r'[^a-zA-Z0-9]', '-', s)
    s = re.sub(r'-+', '-', s)
    return s.strip('-').lower()

  # base_path, _ = os.path.splitext(report_path)
  path = f'{report_config.asset_path}/{safe_name(name)}.png'
  os.makedirs(os.path.dirname(path), exist_ok=True)
  if hasattr(obj, "savefig"):
    obj.savefig(path)
  elif isinstance(obj, str):
    with open(path, "w") as f:
      f.write(obj)
  else:
    raise ValueError("Unsupported asset type: expected figure or string")

  url_path = f"{report_config.asset_url_path}/{safe_name(name)}.png" if report_config.asset_url_path else f"{safe_name(name)}.png"
  report(f'![{name}]({url_path})', clear=clear)