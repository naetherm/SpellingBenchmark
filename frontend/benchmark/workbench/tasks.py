

import random
import string
from celery import task
from .utils import call_regex
import ujson as json
import regex as re
from .builtin_sec import *

@task
def process_uploaded_results(self, list_of_work):
  pass


def predict_builtin(program_name, raw_input, lang_code):
  if program_name.lower() == 'aspell':
    return evaluate_aspell_builtin(raw_input, lang_code)
  elif program_name.lower() == 'xspell':
    return evaluate_xspell_builtin(raw_input, lang_code)
  elif program_name.lower() == 'hunspell':
    return evaluate_hunspell_builtin(raw_input, lang_code)
  elif program_name.lower() == 'pyenchant':
    return evaluate_pyenchant_builtin(raw_input, lang_code)
  elif program_name.lower() == 'mashape':
    return evaluate_mashape_builtin(raw_input, lang_code)
  elif program_name.lower() == 'grammarbot':
    return evaluate_grammarbot_builtin(raw_input, lang_code)
  elif program_name.lower() == 'languagetool':
    return evaluate_languagetool_builtin(raw_input, lang_code)
  elif program_name.lower() == 'norvig':
    return evaluate_norvig_builtin(raw_input, lang_code)
  elif program_name.lower() == 'ngram':
    return evaluate_ngram_builtin(raw_input, lang_code)
  elif program_name.lower() == 'hmm':
    return evaluate_hmm_builtin(raw_input, lang_code)
  else:
    print("UNKNOWN PROGRAM: %s" % (program_name))
    return None
