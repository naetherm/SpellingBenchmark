from django.shortcuts import render, redirect

from django.http import HttpResponse, Http404
from django.shortcuts import get_object_or_404, render
from django.contrib.auth.decorators import login_required
from .forms import AddProgramForm, UploadResultsForm

from .models import Program, Benchmark, Result, ErrorCategory, PredictedSentenceInformation, InternalSentenceInformation

from .tasks import *

import os
import shutil
import random
import string
import requests
import tarfile
import ujson as json

def write_results_to_db(data, program, benchmark):
  """
  Helper method for writing the results to the database.

  :param data: The data to write (as json)
  :param program: the db entry of the program.
  :param benchmark: the db entry of the benchmark.
  """
  Result.objects.filter(program=program, benchmark=benchmark).delete()
  ErrorCategory.objects.filter(program=program, benchmark=benchmark).delete()
  results = Result.objects.create(
    program=program,
    benchmark=benchmark,
    equalScore=data["evaluation"]["equalScore"],
    penalizedScore=data["evaluation"]["penalizedScore"],
    wordAccuracy=data["evaluation"]["wordAccuracy"],
    sequenceAccuracy=data["evaluation"]["sequenceAccuracy"],
    numSentences=data["evaluation"]["numSentences"],
    numErrorFreeSentences=data["evaluation"]["numErrorFreeSentences"],
    numCorrectSentences=data["evaluation"]["numCorrectedSentences"],
    detectionAverageAccuracy=data["evaluation"]["detectionAccuracy"],
    detectionErrorRate=data["evaluation"]["detectionErrorRate"],
    correctionAverageAccuracy=data["evaluation"]["correctionAccuracy"],
    correctionErrorRate=data["evaluation"]["correctionErrorRate"],
    detectionPrecision=data["evaluation"]["detectionPrecision"],
    detectionRecall=data["evaluation"]["detectionRecall"],
    detectionFScore=data["evaluation"]["detectionFScore"],
    correctionPrecision=data["evaluation"]["correctionPrecision"],
    correctionRecall=data["evaluation"]["correctionRecall"],
    correctionFScore=data["evaluation"]["correctionFScore"],
    numTotalWords=data["evaluation"]["numWords"],
    numErrors=data["evaluation"]["numErrors"],
    detectedErrors=data["evaluation"]["detectedErrors"],
    correctedErrors=data["evaluation"]["correctedErrors"],
    suggestionAdequacy=data["evaluation"]["suggestionAdequacy"])
  #results.save()
  for error_type in ["NONE", "NON_WORD", "REAL_WORD", "SPLIT", "HYPHENATION", "COMPOUND_HYPHEN", "CONCATENATION", "CAPITALISATION", "ARCHAIC", "REPEAT", "PUNCTUATION", "MENTION_MISMATCH", "TENSE"]:
    ErrorCategory.objects.create(
      result=results,
      benchmark=benchmark,
      program=program,
      name=error_type,
      detectionPrecision=data["evaluation"][error_type]["detectionPrecision"],
      detectionRecall=data["evaluation"][error_type]["detectionRecall"],
      detectionFScore=data["evaluation"][error_type]["detectionFScore"],
      correctionPrecision=data["evaluation"][error_type]["correctionPrecision"],
      correctionRecall=data["evaluation"][error_type]["correctionRecall"],
      correctionFScore=data["evaluation"][error_type]["correctionFScore"],
      total=data["evaluation"][error_type]["total"],
      found=data["evaluation"][error_type]["found"],
      corrected=data["evaluation"][error_type]["corrected"],
      detection_tp=data["evaluation"][error_type]["detection"]["tp"],
      detection_fp=data["evaluation"][error_type]["detection"]["fp"],
      detection_tn=data["evaluation"][error_type]["detection"]["tn"],
      detection_fn=data["evaluation"][error_type]["detection"]["fn"],
      correction_tp=data["evaluation"][error_type]["correction"]["tp"],
      correction_fp=data["evaluation"][error_type]["correction"]["fp"],
      correction_tn=data["evaluation"][error_type]["correction"]["tn"],
      correction_fn=data["evaluation"][error_type]["correction"]["fn"]
    )

def delete_directory(dir_to_remove):
  """
  Remove directory ``dir_to_remove``.
  """
  shutil.rmtree(dir_to_remove)

import copy




class SourceArticle(object):

  def __init__(self):
    self.sentences = None
    self.tokens = None

def build_source_sentence_representation(input, num_articles, num_sentences):
  json_ = input
  #num_articles = set()
  #for t in json_["tokens"]:
  #  nums_ = re.findall('\d+', t['id'], re.UNICODE)
  #  num_articles.add(int(nums_[0]))
  # count sentences
  #num_sentences = [set() for _ in range(len(num_articles))]
  #for t in json_["tokens"]:
  #  nums_ = re.findall('\d+', t['id'], re.UNICODE)
  #  num_sentences[int(nums_[0])].add(int(nums_[1]))

  results = [SourceArticle() for _ in range(num_articles)]
  for aidx in range(num_articles):
    #for sidx in range(len(num_sentences[aidx])):
    results[aidx].sentences = ["" for _ in range(num_sentences[aidx])]
    results[aidx].tokens = [[] for _ in range(num_sentences[aidx])]

  for t in json_["tokens"]:
    nums_ = re.findall('\d+', t['id'], re.UNICODE)
    results[int(nums_[0])].sentences[int(nums_[1])] += t['token']
    results[int(nums_[0])].tokens[int(nums_[1])].append(t['token'])
    if ((t['space'] == True) or (t['space'] == 'true')):
      results[int(nums_[0])].sentences[int(nums_[1])] += ' '
      

  return copy.deepcopy(results)




class GroundtruthArticle(object):

  def __init__(self):
    self.tokens = None
    self.connections = None
    self.types = None

def build_groundtruth_sentence_representation(input):
  json_ = input
  
  # Count articles
  num_articles = int(json_["information"]["numArticles"])
  num_sentences = []
  for e in list(json_["information"]["sentences"]):
    num_sentences.append(int(e))
  # Got #articles and #sentence per article
  # Build the internal informattion
  results = [GroundtruthArticle() for _ in range(num_articles)]
  for aidx in range(num_articles):
    results[aidx].tokens = [[] for _ in range(num_sentences[aidx])]
    results[aidx].connections = [[] for _ in range(num_sentences[aidx])]
    results[aidx].types = [[] for _ in range(num_sentences[aidx])]

  for t in json_["corrections"]:
    if "-" in t['affected-id']:
      temp_ = t['affected-id'].split("-")
      nums_ = [re.findall('\d+', temp_[0], re.UNICODE)[2], re.findall('\d+', temp_[1], re.UNICODE)[2]]
      sidx_ = re.findall('\d+', temp_[0], re.UNICODE)[1]
      aidx_ = re.findall('\d+', temp_[0], re.UNICODE)[0]
    else:
      nums_ = [re.findall('\d+', t['affected-id'], re.UNICODE)[2]]
      sidx_ = re.findall('\d+', t['affected-id'], re.UNICODE)[1]
      aidx_ = re.findall('\d+', t['affected-id'], re.UNICODE)[0]
    
    results[int(aidx_)].tokens[int(sidx_)].append(t['correct'])
    results[int(aidx_)].types[int(sidx_)].append(t['type'])
    results[int(aidx_)].connections[int(sidx_)].append(nums_)



  return copy.deepcopy(results), num_articles, num_sentences




class AlignmentArticle(object):

  def __init__(self):
    self.tokens = None
    self.src_connections = None
    self.grt_connections = None
    self.corrected = None

def build_alignment_sentence_representation(input):
  json_ = input
  num_articles = 0
  for t in json_["alignments"]:
    nums_ = re.findall('\d+', t['id'], re.UNICODE)
    #articles.add(int(nums_[0]))
    if num_articles < int(nums_[0]):
      num_articles = int(nums_[0])
  num_articles = num_articles + 1
  # count sentences
  num_sentences = [set() for _ in range(num_articles)]
  for t in json_["alignments"]:
    nums_ = re.findall('\d+', t['id'], re.UNICODE)
    num_sentences[int(nums_[0])].add(int(nums_[1]))
  
  results = [AlignmentArticle() for _ in range(num_articles)]
  for e in range(num_articles):
    results[e].tokens = [[] for _ in range(len(num_sentences[e]))]
    results[e].src_connections = [[] for _ in range(len(num_sentences[e]))]
    results[e].grt_connections = [[] for _ in range(len(num_sentences[e]))]
    results[e].corrected = [[] for _ in range(len(num_sentences[e]))]
  
  for t in json_["alignments"]:
    aidx_, sidx_, widx_ = re.findall('\d+', t['id'], re.UNICODE)
    results[int(aidx_)].tokens[int(sidx_)].append(t['token'])
    results[int(aidx_)].corrected[int(sidx_)].append("true" if (t['corrected'] == True) else "false")
    
    pids = list(t['gids'])
    sids = list(t['sids'])
    results[int(aidx_)].grt_connections[int(sidx_)].append([widx_, pids])
    results[int(aidx_)].src_connections[int(sidx_)].append([widx_, sids])

  
  return copy.deepcopy(results)





def read_and_save_alignment_file(program, benchmark, dir_with_alignment_file):

  PredictedSentenceInformation.objects.filter(program=program, benchmark=benchmark).delete()

  filename = dir_with_alignment_file + 'alignments.json'

  file_content = None
  with open(filename, 'r', encoding='utf-8') as fin:
    file_content = json.loads(fin.read())
  
  # TODO: Parse and save to corresponding structure
  results = build_alignment_sentence_representation(file_content)


  num_articles = len(results)

  for aidx in range(num_articles):
    num_sentences = len(results[aidx].tokens)
    for sidx in range(num_sentences):

      src_elems_ = []
      grt_elems_ = []
      for idx, elem in enumerate(results[aidx].src_connections[sidx]):
        src_elems_.append("{}->{}".format(elem[0], ",".join(str(e) for e in elem[1:])))
      for idx, elem in enumerate(results[aidx].grt_connections[sidx]):
        grt_elems_.append("{}->{}".format(elem[0], ",".join(str(e) for e in elem[1:])))

      PredictedSentenceInformation.objects.create(
        program=program,
        benchmark=benchmark,
        aid=aidx,
        sid=sidx,
        tokens=results[aidx].tokens[sidx],
        corrected=results[aidx].corrected[sidx],
        src_connections="|".join(e for e in src_elems_),
        tgt_connections="|".join(e for e in grt_elems_)
      )

def receive_sentences_for_benchmark_new(benchmark, sidx_value, aidx_value):
  sentences = InternalSentenceInformation.objects.filter(benchmark=benchmark, aidx=aidx_value, sidx=sidx_value).order_by('aidx', 'sidx')

  return sentences

def receive_predictions_for_benchmark_new(benchmark, program, sidx_value, aidx_value):
  predictions = PredictedSentenceInformation.objects.filter(program=program, benchmark=benchmark, aid=aidx_value, sid=sidx_value).order_by('aid', 'sid')

  return predictions

def receive_all_sentences_for_benchmark(benchmark):
  sentences = InternalSentenceInformation.objects.filter(benchmark=benchmark).order_by('aidx', 'sidx')

  return sentences

def receive_all_predictions_for_benchmark(benchmark, program):
  predictions = PredictedSentenceInformation.objects.filter(program=program, benchmark=benchmark).order_by('aid', 'sid')

  return predictions


##
## DEPRECATED
##
def receive_sentences_for_benchmark(benchmark):
  sentences = InternalSentenceInformation.objects.filter(benchmark=benchmark).order_by('aidx', 'sidx')

  return sentences

def receive_predictions_for_benchmark(benchmark, program):
  predictions = PredictedSentenceInformation.objects.filter(program=program, benchmark=benchmark).order_by('aid', 'sid')

  return predictions