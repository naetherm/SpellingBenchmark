

import random
import string
import time
from celery import task
from .utils import call_regex
import ujson as json
import regex as re

def handle_uploaded_file(f):
  filename = ''.join(random.choice(string.ascii_lowercase) for i in range(32))
  filepath = '/tmp/' + filename + '.tar.gz'
  with open(filepath, 'wb+') as ftemp:
    for chunk in f.chunks():
      ftemp.write(chunk)

  return filepath


import copy

class SourceInternalArticle(object):

  def __init__(self):
    self.sentences = None

def build_article_information(input):
  json_ = json.loads(input)
  articles = set()
  for t in json_["tokens"]:
    nums_ = re.findall('\d+', t['id'], re.UNICODE)
    articles.add(int(nums_[0]))
  # count sentences
  num_articles = len(articles)
  #print(f"detected {num_articles} in source file, collect number of sentences")
  num_sentences = [set() for _ in range(num_articles)]
  for t in json_["tokens"]:
    nums_ = re.findall('\d+', t['id'], re.UNICODE)
    num_sentences[int(nums_[0])].add(int(nums_[1]))

  results = [SourceInternalArticle() for _ in range(num_articles)]
  for aidx in range(num_articles):
    #print(f"detected {len(num_sentences[aidx])} sentences for article {aidx}")
    #for sidx in range(len(num_sentences[aidx])):
    results[aidx].sentences = ["" for _ in range(len(num_sentences[aidx]))]

  for t in json_["tokens"]:
    nums_ = re.findall('\d+', t['id'], re.UNICODE)
    results[int(nums_[0])].sentences[int(nums_[1])] += t['token']
    if ((t['space'] == True) or (t['space'] == 'true')):
      results[int(nums_[0])].sentences[int(nums_[1])] += ' '

  return copy.deepcopy(results)

def generate_token_information(aidx, sidx, tidx, token, suggestions, space, add_comma, proposed_type=None):
  if token == "\\":
    print("WARNING: %d %d %d %s" % (aidx, sidx, tidx, token))
  result = "  {"

  if isinstance(tidx, list):
    result += "\"id\": \"a" + str(aidx) + ".s" + str(sidx) + ".w" + str(tidx[0]) + "-a" + str(aidx) + ".s" + str(sidx) + ".w" + str(tidx[1]) + "\", "
  else:
    result += "\"id\": \"a" + str(aidx) + ".s" + str(sidx) + ".w" + str(tidx) + "\", "
  if proposed_type != None:
    result += "\"type\": \"" + proposed_type + "\", "
  result += "\"token\": \"" + token.replace("\\", "\\\\").replace("\"", "\\\"") + "\", "

  result += "\"suggestions\": ["

  for idx, suggestion in enumerate(suggestions):
    result += "\"" + suggestion.replace("\\", "\\\\").replace("\"", "\\\\\"") + "\""
    if idx < (len(suggestions)-1):
      result += ", "

  result += "], \"space\": "

  if space:
    result += "true"
  else:
    result += "false"

  if add_comma:
    result += "},\n"
  else:
    result += "}"

  return result



def evaluate_aspell_builtin(input, lang_code):
  """
  """
  import enchant
  import aspell

  input = build_article_information(input)

  result_content = "{ \"predictions\": [\n"

  for aidx, article in enumerate(input):
    for sidx, sentence in enumerate(article.sentences):
      chkr = aspell.Speller('lang', lang_code.split("_")[0])
      tokens, spaces = call_regex(sentence)

      shift = 0

      for tidx, t in enumerate(tokens):
        if t == "\"":
          t = t.replace("\"", "\\\"")
        if t == "\\":
          t = t.replace("\\", "\\\\")
        token = t
        suggestions = []
        try:
          if chkr.check(t) == False:
            sugg = chkr.suggest(t)
            if len(sugg) > 0:
              tempSuggestion = sugg[0].strip()
              if (" " in tempSuggestion):
                multi_tokens = tempSuggestion.split(" ")
                token = None
              else:
                token = tempSuggestion
                suggestions = sugg[1:]
        except:
          token = t
        
        if token == None: # is none, so tokens is filled with multiple elements -> splitted word
          num_tokens = len(multi_tokens)
          for idx, t in enumerate(multi_tokens):
            result_content += generate_token_information(
              aidx,
              sidx,
              tidx+idx,
              t,
              suggestions,
              spaces[tidx],
              tidx < (len(tokens) - 1)
            )
          shift += num_tokens - 1
        else:
          result_content += generate_token_information(
            aidx,
            sidx,
            tidx+shift,
            token,
            suggestions,
            spaces[tidx],
            tidx < (len(tokens) - 1)
          )
      if (aidx < (len(input) - 1)) or (sidx < len(article.sentences) - 1):
        result_content += ",\n"

  result_content += "  ]\n}"

  #print("DEBUG: ")
  #print(result_content)

  return result_content

def evaluate_hunspell_builtin(input, lang_code):
  from hunspell import HunSpell

  #hobj = HunSpell(lang_code)
  hobj = HunSpell("/usr/share/hunspell/"+lang_code+".dic", "/usr/share/hunspell/"+lang_code+".aff")

  input = build_article_information(input)

  result_content = "{ \"predictions\": [\n"
  for aidx, article in enumerate(input):
    for sidx, sentence in enumerate(article.sentences):

      tokens, spaces = call_regex(sentence)

      realNumTokens = len(tokens)
      shift = 0

      for tidx, t in enumerate(tokens):

        token = t
        splitTokens = None
        suggestions = []
        try:
          if (hobj.spell(t) == False):
            if len(hobj.suggest(t)) > 0:
              token = hobj.suggest(t)[0] # Get the first element form the suggestions
              token = token.strip()
              if " " in token:
                print("Split token: ", token)
                splitTokens = token.split(" ")
                realNumTokens += len(splitTokens) - 1
                token = None
            if (len(hobj.suggest(t)) > 1):
              suggestions = hobj.suggest(t)[1:]
          else:
            token = t
        except:
          token = t
        if splitTokens is not None:
          for tt in splitTokens:
            result_content += generate_token_information(
              aidx,
              sidx,
              tidx+shift,
              tt,
              suggestions,
              spaces[tidx],
              tidx+shift < (realNumTokens - 1)
            )
            shift += 1
          shift -= 1
        else:
          result_content += generate_token_information(
            aidx,
            sidx,
            tidx+shift,
            token,
            suggestions,
            spaces[tidx],
            tidx+shift < (realNumTokens - 1)
          )
      if (aidx < (len(input) - 1)) or (sidx < len(article.sentences) - 1):
        result_content += ",\n"

  result_content += "  ]\n}"

  return result_content

def evaluate_mashape_builtin(input, lang_code):
  import http.client, urllib.request, urllib.parse, json
  import requests
  MS_KEY = "13daa1be07msh5f08fe12c3c9b41p156adcjsn4f9c058f2b15"

  MS_HOST = 'montanaflynn-spellcheck.p.rapidapi.com'
  MS_PATH = '/check/?'
  MS_PARAMS = 'text'

  MS_HEADERS = {
    'X-RapidAPI-Key': MS_KEY
  }

  input = build_article_information(input)

  result_content = "{ \"predictions\": [\n"

  for aidx, article in enumerate(input):
    for sidx, sentence in enumerate(article.sentences):
      #print("INPUT: %s" % (sentence))
      response = requests.get(
        'https://montanaflynn-spellcheck.p.rapidapi.com/check/?text="{}"'.format(sentence),
        headers={'X-RapidAPI-Key': MS_KEY}
      )

      jsonified = response.json()
      requested = jsonified["suggestion"]

      #print("SUGGESTION: %s" % (requested))

      suggestions = {}

      for key, value in jsonified["corrections"].items():
        if len(value) > 1:
          suggestions[value[0]] = value[1:]
      tokens, spaces = call_regex(requested)
      shift = 0
      realNumTokens = len(tokens)
      for tidx, token in enumerate(tokens):
        token = token.strip()
        if " " in token  and ((len(token.split(" ")[0]) != 0) and (len(token.split(" ")[0]) != 0)):
          realNumTokens += len(token.split(" ")) - 1
          for tt in token.split(" "):
            result_content += generate_token_information(
              aidx,
              sidx,
              tidx+shift,
              tt,
              suggestions[tidx] if tidx in suggestions else [],
              spaces[tidx],
              tidx+shift < (realNumTokens - 1)
            )
            shift += 1
          shift -= 1
        else:
          result_content += generate_token_information(
            aidx,
            sidx,
            tidx+shift,
            token,
            suggestions[tidx] if tidx in suggestions else [],
            spaces[tidx],
            tidx+shift < (realNumTokens - 1)
          )
      if (aidx < (len(input) - 1)) or (sidx < len(article.sentences) - 1):
        result_content += ",\n"

  result_content += "  ]\n}"

  return result_content

def evaluate_xspell_builtin(input, lang_code):
  import html
  import requests

  input = build_article_information(input)


  result_content = "{ \"predictions\": [\n"

  for aidx, article in enumerate(input):
    for sidx, sentence in enumerate(article.sentences):
      #php_program = '<?php $xt = "b8338740118776a5db31f7c2d5c10734";$xs = "%s";$xu = "http://xspell.ga";$xp = "api=spell&token=$xt&check=$xs";$x = curl_init();curl_setopt($x,CURLOPT_POST,1);curl_setopt($x,CURLOPT_POSTFIELDS,$xp);curl_setopt($x,CURLOPT_URL,$xu);curl_setopt($x,CURLOPT_RETURNTRANSFER,1);$output = curl_exec($x);print($output);?>' % (sentence.replace('"', '\"'));

      #with open('/tmp/main.php', 'w') as fout:
      #  fout.write(php_program)
      #proc = subprocess.Popen("php -f /tmp/main.php", shell=True, stdout=subprocess.PIPE)

      #response = proc.stdout.read()
      #response = html.unescape(response.decode('utf-8'))
      XSPELL_TOKEN = "b8338740118776a5db31f7c2d5c10734"

      response = requests.get("http://xspell.ga/?api=spell&token=%s&check=%s" % (XSPELL_TOKEN, sentence)).text

      tokens, spaces = call_regex(response)
      for tidx, token in enumerate(tokens):
        token = token.strip()
        result_content += generate_token_information(
          aidx,
          sidx,
          tidx,
          token,
          [],
          spaces[tidx],
          tidx < (len(tokens) - 1)
        )
      if (aidx < (len(input) - 1)) or (sidx < len(article.sentences) - 1):
        result_content += ",\n"

  result_content += "  ]\n}"

  return result_content

def evaluate_languagetool_builtin(input, lang_code):
  import time
  import pylanguagetool
  import requests

  LT_API_URL = "https://languagetool.org/api/v2/"

  def wordpos2token(word_pos, tkns, spcs):
    char_counter = 0
    for tidx, t in enumerate(tkns):
      if word_pos == char_counter:
        return tidx
      char_counter += len(t)
      if spcs[tidx] == True:
        char_counter += 1
      if tidx == len(tkns):
        return tidx
    return (len(tkns)-1)

  def wordpos2tokens(word_pos, length, tkns, spcs):
    """
    Returns a tuple of start token and end token
    """
    results = []
    char_counter = 0
    for tidx, t in enumerate(tkns):
      if (word_pos+length) <= char_counter:
        #results.append(tidx-1)
        return results
      if char_counter >= word_pos:
        results.append(tidx)
      char_counter += len(t)
      if spcs[tidx] == True:
        char_counter += 1
      if tidx == len(tkns):
        return [tidx]
    return [len(tkns)-1]

  input = build_article_information(input)

  result_content = "{ \"predictions\": [\n"

  for aidx, article in enumerate(input):
    for sidx, sentence in enumerate(article.sentences):
      # We will need this to restructure the sentence
      dummy_tokens, dummy_spaces = call_regex(sentence)
      tokens, spaces = call_regex(sentence)

      # It seems that we get blocked by the languagetool servers ...
      time.sleep(2)

      suggestions = {}

      shift = 0

      params = {
        "text": sentence,
        "language": lang_code.split('_')[0]
      }

      response = requests.post(
        LT_API_URL + "check",
        data=params
      )
      response = response.json()

      for idx, match in enumerate(response['matches']):
        offset = match["offset"]
        length = match["length"]
        repls = match["replacements"]
        #tidx = wordpos2token(offset, dummy_tokens, dummy_spaces)
        '''
        tidxs = wordpos2tokens(offset, length, dummy_tokens, dummy_spaces)

        if (len(repls) > 0):
          temp_ = repls[0]["value"].replace("\\", "\\\\").replace("\"", "\\\\\"")
          if (" " in temp_ and (len(tidxs) > 1) and (tidxs[0] != tidxs[1])):
            tokens[tidxs[0]] = temp_.split(" ")[0]
            tokens[tidxs[1]] = temp_.split(" ")[1]
          else:
            tokens[tidxs[0]] = repls[0]["value"].replace("\\", "\\\\").replace("\"", "\\\\\"")
            if ((len(tidxs) > 1) and (tidxs[0] != tidxs[1])):
              del tokens[tidxs[1]: tidxs[-1]]
          if (len(repls) > 1):
            suggestions[tidxs[0]] = []
            for v in repls[1:]:
              suggestions[tidxs[0]].append(v["value"].replace("\\", "\\\\").replace("\"", "\\\\\""))
        else:
          pass
        '''
        tidxs = wordpos2tokens(offset, length, dummy_tokens, dummy_spaces)

        if (len(repls) > 0):
          repl_tokens = repls[0]["value"].replace("\\", "\\\\").replace("\"", "\\\\\"").split(" ")
          # Just one token or multiple ones?
          if len(repl_tokens) == 1:
            tokens[tidxs[0]+shift] = repls[0]["value"].replace("\\", "\\\\").replace("\"", "\\\\\"")
            #rules[tidxs[0]] = rule
          else:
            # Otherwise replace multiple tokens
            if len(tidxs) == len(repl_tokens):
              for iidx, tidx in enumerate(tidxs):
                tokens[tidx+shift] = repl_tokens[iidx]
            else:
              # Not that trivial, delete everything and fill in reverse ordering
              if len(tidxs) == 1:
                #
                #print("-> delete token at {} [Shift={}]".format(tidxs[0]+shift, shift))
                del tokens[tidxs[0]+shift]
                del spaces[tidxs[0]+shift]
              else:
                del tokens[tidxs[0]+shift: tidxs[-1]+shift+1]
                del spaces[tidxs[0]+shift: tidxs[-1]+shift+1]
              repl_tokens.reverse()
              for e in repl_tokens:
                #print("-> adding token {} at position {} [Shift={}]".format(e, tidxs[0]+shift, shift))
                tokens.insert(tidxs[0]+shift, e)
                spaces.insert(tidxs[0]+shift, True)
              shift += len(repl_tokens) - len(tidxs)
          if (len(repls) > 1):
            suggestions[tidxs[0]] = []
            for v in repls[1:]:
              suggestions[tidxs[0]].append(v["value"].replace("\\", "\\\\").replace("\"", "\\\\\""))#.replace("\\", "\\\\").replace("\"", "\\\\\""))
        else:
          pass

      #tokens, spaces = call_regex(response)
      realNumTokens = len(tokens)
      shift = 0
      for tidx, token in enumerate(tokens):
        token = token.strip()
        if " " in token  and ((len(token.split(" ")[0]) != 0) and (len(token.split(" ")[0]) != 0)):
          realNumTokens += len(token.split(" ")) - 1
          for tt in token.split(" "):
            result_content += generate_token_information(
              aidx,
              sidx,
              tidx+shift,
              tt,
              suggestions[tidx] if tidx in suggestions else [],
              spaces[tidx],
              tidx+shift < (realNumTokens - 1)
            )
            shift += 1
          shift -= 1
        else:
          result_content += generate_token_information(
            aidx,
            sidx,
            tidx+shift,
            token,
            suggestions[tidx] if tidx in suggestions else [],
            spaces[tidx],
            tidx+shift < (realNumTokens - 1)
          )
      if (aidx < (len(input) - 1)) or (sidx < len(article.sentences) - 1):
        result_content += ",\n"

  result_content += "  ]\n}"

  #print("DEBUGGING: %s" % (result_content))

  return result_content

def evaluate_pyenchant_builtin(input, lang_code):
  import enchant
  from enchant.checker import SpellChecker

  input = build_article_information(input)

  result_content = "{ \"predictions\": [\n"

  for aidx, article in enumerate(input):
    for sidx, sentence in enumerate(article.sentences):
      chkr = SpellChecker(lang_code)

      chkr.set_text(sentence)
      suggestions = {}

      # We will need this to restructure the sentence
      dummy_tokens, dummy_spaces = call_regex(sentence)
      tokens, spaces = call_regex(sentence)

      def wordpos2token(word_pos, tkns, spcs):
        char_counter = 0
        for tidx, t in enumerate(tkns):
          if word_pos == char_counter:
            return tidx
          char_counter += len(t)
          if spcs[tidx] == True:
            char_counter += 1
          if tidx == len(tkns):
            return tidx
        return (len(tkns)-1)

      for err in chkr:
        word_pos = err.wordpos
        tidx = wordpos2token(word_pos, dummy_tokens, dummy_spaces)
        suggests = err.suggest()
        if len(suggests) == 1:
          tokens[tidx] = suggests[0].replace("\\", "\\\\").replace("\"", "\\\\\"")
        elif len(suggests) > 1:
          tokens[tidx] = suggests[0].replace("\\", "\\\\").replace("\"", "\\\\\"")
          suggestions[tidx] = [sugg.replace("\\", "\\\\").replace("\"", "\\\\\"") for sugg in suggests[1:]]
        elif len(suggests) == 0:
          tokens[tidx] = err.word.replace("\\", "\\\\").replace("\"", "\\\\\"")
          word_pos = err.wordpos
        if tokens[tidx] == "\\":
          tokens[tidx] = "\\\\"


      #tokens, spaces = call_regex(response)
      realNumTokens = len(tokens)
      shift = 0
      for tidx, token in enumerate(tokens):
        token = token.strip()
        
        if " " in token and ((len(token.split(" ")[0]) != 0) and (len(token.split(" ")[0]) != 0)):
          realNumTokens += len(token.split(" ")) - 1
          for tt in token.split(" "):
            result_content += generate_token_information(
              aidx,
              sidx,
              tidx+shift,
              tt,
              suggestions[tidx] if tidx in suggestions else [],
              dummy_spaces[tidx],
              tidx+shift < (realNumTokens - 1)
            )
            shift += 1
          shift -= 1
        else:
          result_content += generate_token_information(
            aidx,
            sidx,
            tidx+shift,
            token,
            suggestions[tidx] if tidx in suggestions else [],
            dummy_spaces[tidx],
            tidx+shift < (realNumTokens - 1)
          )
      if (aidx < (len(input) - 1)) or (sidx < len(article.sentences) - 1):
        result_content += ",\n"

  result_content += "  ]\n}"

  return result_content

def evaluate_grammarbot_builtin(input, lang_code):
  #import requests
  from grammarbot import GrammarBotClient

  client = GrammarBotClient()

  # or, signup for an API Key to get higher usage limits here: https://www.grammarbot.io/
  client = GrammarBotClient(api_key='AF5B9M2X') # GrammarBotClient(api_key=my_api_key_here)


  def wordpos2token(word_pos, length, tkns, spcs):
    char_counter = 0
    for tidx, t in enumerate(tkns):
      if word_pos == char_counter:
        return tidx
      char_counter += len(t)
      if spcs[tidx] == True:
        char_counter += 1
      if tidx == len(tkns):
        return tidx
    return (len(tkns)-1)

  def wordpos2tokens(word_pos, length, tkns, spcs):
    """
    Returns a tuple of start token and end token
    """
    results = []
    char_counter = 0
    for tidx, t in enumerate(tkns):
      if (word_pos+length) <= char_counter:
        #results.append(tidx-1)
        return results
      if char_counter >= word_pos:
        results.append(tidx)
      char_counter += len(t)
      if spcs[tidx] == True:
        char_counter += 1
      if tidx == len(tkns):
        return [tidx]
    return [len(tkns)-1]

  GB_KEY = "AF5B9M2X"

  input = build_article_information(input)

  def translate_grammarbot_rules(rule):
    if rule == "CONFUSION_RULE":
      return "REAL_WORD"
    else:
      return None

  result_content = "{ \"predictions\": [\n"

  for aidx, article in enumerate(input):

    for sidx, sentence in enumerate(article.sentences):

      dummy_tokens, dummy_spaces = call_regex(sentence)
      tokens, spaces = call_regex(sentence)
      suggestions = {}
      rules = {}

      shift = 0

      #params = {
      #  "language": "en-US",
      #  "api_key": GB_KEY,
      #  "text": sentence
      #}
      #header = {
      #  "Content-Type": "application/json"
      #}

      #response = requests.get(
      #  'http://api.grammarbot.io/v2/check',
      #  params=params,
      #  headers=header
      #)
      #response = response.json()
      try:
        result = client.check(sentence, lang_code.replace('_', '-'))

        shift = 0

        for idx, match in enumerate(result.matches):
          offset = match.replacement_offset
          length = match.replacement_length
          repls = match.replacements
          rule = match.rule
          #tidx = wordpos2token(offset, dummy_tokens, dummy_spaces)
          tidxs = wordpos2tokens(offset, length, dummy_tokens, dummy_spaces)

          repl_tokens = repls[0].split(" ")

          if (len(repls) > 0):
            # Just one token or multiple ones?
            if len(repl_tokens) == 1:
              tokens[tidxs[0]+shift] = repls[0]#.replace("\\", "\\\\").replace("\"", "\\\\\"")
              rules[tidxs[0]] = rule
            else:
              # Otherwise replace multiple tokens
              if len(tidxs) == len(repl_tokens):
                for iidx, tidx in enumerate(tidxs):
                  tokens[tidx+shift] = repl_tokens[iidx]
              else:
                # Not that trivial, delete everything and fill in reverse ordering
                print("repls[0]: {}".format(repls[0]))
                print("tidxs: {}".format(tidxs))
                if len(tidxs) == 1:
                  #
                  #print("-> delete token at {} [Shift={}]".format(tidxs[0]+shift, shift))
                  del tokens[tidxs[0]+shift]
                  del spaces[tidxs[0]+shift]
                else:
                  del tokens[tidxs[0]+shift: tidxs[-1]+shift+1]
                  del spaces[tidxs[0]+shift: tidxs[-1]+shift+1]
                repl_tokens.reverse()
                for e in repl_tokens:
                  #print("-> adding token {} at position {} [Shift={}]".format(e, tidxs[0]+shift, shift))
                  tokens.insert(tidxs[0]+shift, e)
                  spaces.insert(tidxs[0]+shift, True)
                shift += len(repl_tokens) - len(tidxs)
            if (len(repls) > 1):
              suggestions[tidxs[0]] = []
              for v in repls[1:]:
                suggestions[tidxs[0]].append(v)#.replace("\\", "\\\\").replace("\"", "\\\\\""))
          else:
            pass
      except:
        pass#rules[tidx] = "None"

      realNumTokens = len(tokens)
      shift = 0
      for tidx, token in enumerate(tokens):
        token = token.strip()
        if " " in token and ((len(token.split(" ")[0]) != 0) and (len(token.split(" ")[0]) != 0)):
          realNumTokens += len(token.split(" ")) - 1
          for tt in token.split(" "):
            result_content += generate_token_information(
              aidx,
              sidx,
              tidx+shift,
              tt,
              suggestions[tidx] if tidx in suggestions else [],
              spaces[tidx],
              tidx+shift < (realNumTokens - 1),
              translate_grammarbot_rules(rules[tidx]) if tidx in rules else None
            )
            shift += 1
          shift -= 1
        else:
          result_content += generate_token_information(
            aidx,
            sidx,
            tidx+shift,
            token,
            suggestions[tidx] if tidx in suggestions else [],
            spaces[tidx],
            tidx+shift < (realNumTokens - 1),
            translate_grammarbot_rules(rules[tidx]) if tidx in rules else None
          )
      if (aidx < (len(input) - 1)) or (sidx < len(article.sentences) - 1):
        result_content += ",\n"

  result_content += "  ]\n}"

  return result_content


def evaluate_norvig_builtin(input, lang_code):
  import re
  from collections import Counter

  def words(text): return re.findall(r'\w+', text.lower())

  if lang_code == "en_US":
    WORDS = Counter(words(open('/code/benchmark/workbench/dict/american-english-insane').read()))
  else:
    WORDS = Counter()

  def P(word, N=sum(WORDS.values())):
    "Probability of `word`."
    return WORDS[word] / N

  def correction(word):
    "Most probable spelling correction for word."
    return max(candidates(word), key=P)

  def candidates(word):
    "Generate possible spelling corrections for word."
    return (known([word]) or known(edits1(word)) or known(edits2(word)) or [word])

  def known(words):
    "The subset of `words` that appear in the dictionary of WORDS."
    return set(w for w in words if w in WORDS)

  def edits1(word):
    "All edits that are one edit away from `word`."
    letters    = 'abcdefghijklmnopqrstuvwxyz'
    splits     = [(word[:i], word[i:])    for i in range(len(word) + 1)]
    deletes    = [L + R[1:]               for L, R in splits if R]
    transposes = [L + R[1] + R[0] + R[2:] for L, R in splits if len(R)>1]
    replaces   = [L + c + R[1:]           for L, R in splits if R for c in letters]
    inserts    = [L + c + R               for L, R in splits for c in letters]
    return set(deletes + transposes + replaces + inserts)

  def edits2(word):
    "All edits that are two edits away from `word`."
    return (e2 for e1 in edits1(word) for e2 in edits1(e1))


  input = build_article_information(input)

  result_content = "{ \"predictions\": [\n"

  for aidx, article in enumerate(input):
    for sidx, sentence in enumerate(article.sentences):

      tokens, spaces = call_regex(sentence)
      suggestions = {}

      for tidx, token in enumerate(tokens):
        edits = list(candidates(token))
        #print("edits: %s" % (edits))
        proposed_token = edits[0] if len(edits) > 0 else token
        suggestions = []
        for s in edits[1:]:
          suggestions.append(s)
        result_content += generate_token_information(
          aidx,
          sidx,
          tidx,
          edits[0],
          suggestions,
          spaces[tidx],
          tidx < (len(tokens) - 1)
        )
      if (aidx < (len(input) - 1)) or (sidx < len(article.sentences) - 1):
        result_content += ",\n"

  result_content += "  ]\n}"

  return result_content

def evaluate_ngram_builtin(input, lang_code):

  from .ngram import Autocorrect, evaluate

  autocorrect = Autocorrect(3, 1)

  input = build_article_information(input)

  result_content = "{ \"predictions\": [\n"

  for aidx, article in enumerate(input):
    for sidx, sentence in enumerate(article.sentences):

      tokens, spaces = call_regex(sentence)

      for tidx, token in enumerate(tokens):
        result = evaluate(autocorrect, token)

        if isinstance(result, list):
          token = result[0]
          if (len(result) > 1):
            sugg = result[1:]
          else:
            sugg = []
        else:
          token = result
          sugg = []
        result_content += generate_token_information(
          aidx,
          sidx,
          tidx,
          token,
          sugg,
          spaces[tidx],
          tidx < (len(tokens) - 1)
        )
      if (aidx < (len(input) - 1)) or (sidx < len(article.sentences) - 1):
        result_content += ",\n"

  result_content += "  ]\n}"

  return result_content


def evaluate_hmm_builtin(input, lang_code):

  from .hmm import SpellingCorrection, Viterbi

  print("Start training of HMM model ...")
  objSC = SpellingCorrection()
  objSC.trainHMModel()
  objViterbi = Viterbi(objSC.getEmissionProbabilities(), objSC.getTransitionProbabilities(), objSC.corruptedTestSet)
  print("\t finished training.")

  input = build_article_information(input)

  result_content = "{ \"predictions\": [\n"

  for aidx, article in enumerate(input):
    for sidx, sentence in enumerate(article.sentences):

      tokens, spaces = call_regex(sentence.lower())

      tokens = objViterbi.process(tokens)

      for tidx, token in enumerate(tokens):
        result_content += generate_token_information(
          aidx,
          sidx,
          tidx,
          token,
          [],
          spaces[tidx],
          tidx < (len(tokens) - 1)
        )
      if (aidx < (len(input) - 1)) or (sidx < len(article.sentences) - 1):
        result_content += ",\n"

  result_content += "  ]\n}"

  return result_content
