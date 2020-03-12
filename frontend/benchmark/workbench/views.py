from django.shortcuts import render, redirect

from django.http import HttpResponse, Http404, JsonResponse
from django.shortcuts import get_object_or_404, render
from django.contrib.auth.decorators import login_required
from .forms import AddProgramForm, UploadResultsForm

from .models import Program, Benchmark, Result, ErrorCategory, InternalSentenceInformation, PredictedSentenceInformation
from .helpers import *

from .tasks import *

import os
import shutil
import random
import string
import requests
import tarfile
import json
#from django.core.serializers.json import DjangoJSONEncoder
import ujson as json

def index(request):
  """
  The index page.
  """
  context = {
    'user': request.user,
    'programs': Program.objects.order_by('program_name'),
    'benchmarks': Benchmark.objects.order_by('benchmark_name')
  }
  return render(request, 'workbench/index.html', context)

@login_required(login_url='/user/login/')
def profile(request):
  """
  Returns the profile page of the currently logged in user.

  :param request: The request.
  """

  context = {
    'user': request.user
  }
  return render(request, 'workbench/profile.html', context)

def programs(request):
  """
  Returns a page, containing a list of all programs that are currently registered
  and by default enabled for comparison reasons.

  :param request: The request.
  """
  program_list = Program.objects.order_by('program_name')
  context = {
    'program_list': program_list,
    'user': request.user
  }

  return render(request, 'workbench/programs.html', context)

@login_required(login_url='/user/login/')
def add_program(request):
  """
  Adds a new program to the database.
  """
  if request.method == 'POST':
    form = AddProgramForm(request.POST)

    if form.is_valid():
      form.save(user=request.user)

    return redirect('/programs/')
  else:
    form = AddProgramForm()

    context = {
      'form': form
    }

    return render(request, 'workbench/add_program.html', context)

def program(request, program_id):
  """
  Returns a page, containing information about a specific program given by @p
  program_id.

  :param request: The request.
  :param program_id: The unique program ID.
  """

  program = get_object_or_404(Program, pk=program_id)

  return render(request, 'workbench/program.html', {'program': program, 'user': request.user})

def benchmarks(request):
  """
  Returns a page, containing a list of all benchmarks that are currently registered.

  :param request: The request.
  """
  benchmark_list = Benchmark.objects.order_by('benchmark_name')

  context = {
    'benchmark_list': benchmark_list,
    'user': request.user
  }

  return render(request, 'workbench/benchmarks.html', context)

def benchmark(request, benchmark_id):
  """
  Returns the results view of one specific benchmark, given by @p benchmark_id.

  :param request: The request.
  :param benchmark_id: The unique ID of a benchmark instance.
  """
  benchmark = get_object_or_404(Benchmark, pk=benchmark_id)

  programs = Program.objects.order_by('program_name')
  results = Result.objects.filter(benchmark=benchmark_id)
  sentences = receive_sentences_for_benchmark(benchmark_id)

  # DEPRECATED: categories = ErrorCategory.objects.filter(benchmark=benchmark_id)

  js_program_names = json.dumps([p.program_name for p in programs])


  # Filter everything here

  context = {
    'benchmark': benchmark,
    'programs': programs,
    'results': results,
    'sentences': sentences,
    'js_program_names': js_program_names,
    'user': request.user
  }

  NONE_TABLE = {}
  NON_WORD_TABLE = {}
  REAL_WORD_TABLE = {}
  SPLIT_TABLE = {}
  HYPHENATION_TABLE = {}
  COMPOUND_HYPHEN_TABLE = {}
  CONCATENATION_TABLE = {}
  CAPITALISATION_TABLE = {}
  REPEAT_TABLE = {}
  ARCHAIC_TABLE = {}
  PUNCTUATION_TABLE = {}
  TENSE_TABLE = {}
  MENTION_MISMATCH_TABLE = {}

  for program in programs:
    sub_categories = ErrorCategory.objects.filter(benchmark=benchmark_id, program=program.id)

    if sub_categories.count() > 0:

      #print("sub_categories[NONE]: %s" % (sub_categories.filter(name="NONE")[:1].get()))

      NONE_TABLE[program.program_name] = sub_categories.filter(name="NONE")[:1].get()
      NON_WORD_TABLE[program.program_name] = sub_categories.filter(name="NON_WORD")[:1].get()
      REAL_WORD_TABLE[program.program_name] = sub_categories.filter(name="REAL_WORD")[:1].get()
      SPLIT_TABLE[program.program_name] = sub_categories.filter(name="SPLIT")[:1].get()
      HYPHENATION_TABLE[program.program_name] = sub_categories.filter(name="HYPHENATION")[:1].get()
      COMPOUND_HYPHEN_TABLE[program.program_name] = sub_categories.filter(name="COMPOUND_HYPHEN")[:1].get()
      CONCATENATION_TABLE[program.program_name] = sub_categories.filter(name="CONCATENATION")[:1].get()
      CAPITALISATION_TABLE[program.program_name] = sub_categories.filter(name="CAPITALISATION")[:1].get()
      REPEAT_TABLE[program.program_name] = sub_categories.filter(name="REPEAT")[:1].get()
      ARCHAIC_TABLE[program.program_name] = sub_categories.filter(name="ARCHAIC")[:1].get()
      PUNCTUATION_TABLE[program.program_name] = sub_categories.filter(name="PUNCTUATION")[:1].get()
      MENTION_MISMATCH_TABLE[program.program_name] = sub_categories.filter(name="MENTION_MISMATCH")[:1].get()
      TENSE_TABLE[program.program_name] = sub_categories.filter(name="TENSE")[:1].get()

  context["NONE"] = NONE_TABLE
  context["NON_WORD"] = NON_WORD_TABLE
  context["REAL_WORD"] = REAL_WORD_TABLE
  context["SPLIT"] = SPLIT_TABLE
  context["HYPHENATION"] = HYPHENATION_TABLE
  context["COMPOUND_HYPHEN"] = COMPOUND_HYPHEN_TABLE
  context["CONCATENATION"] = CONCATENATION_TABLE
  context["CAPITALISATION"] = CAPITALISATION_TABLE
  context["REPEAT"] = REPEAT_TABLE
  context["ARCHAIC"] = ARCHAIC_TABLE
  context["PUNCTUATION"] = PUNCTUATION_TABLE
  context["MENTION_MISMATCH"] = MENTION_MISMATCH_TABLE
  context["TENSE"] = TENSE_TABLE

  return render(request, 'workbench/benchmark.html', context)

def download_data(request, benchmark_id):
  """
  Download the data of a specific benchmark, given by the unique ID of the benchmark.

  :param request: The request.
  :param benchmark_id: The unique ID of the benchmark.
  """

  benchmark = get_object_or_404(Benchmark, pk=benchmark_id)

  with open(benchmark.download_file, 'r') as fout:
    response = HttpResponse(fout.read(), content_type="application/json")
    response['Content-Disposition'] = 'attachment; filename=benchmark.json'
    return response

def receive_groundtruth(request, benchmark_id):
  """
  Returns the groundtruth of a specific benchmark.

  :param request: The request.
  :param benchmark_id: The unique ID of the benchmark.
  """

  benchmark = get_object_or_404(Benchmark, pk=benchmark_id)

  with open(benchmark.groundtruth_file, 'rb') as fout:
    response = HttpResponse(fout.read(), content_type="application/tar+gzip")
    response['Content-Disposition'] = 'attachment; filename=groundtruth.tar.gz'
    return response

def results(request, benchmark_id):
  """
  Returns a page, containing the results for a specific benchmark, given by its
  unique benchmark ID.

  :param request: The request.
  :param benchmark_id: The unique benchmark ID.
  """
  return HttpResponse("Results of program <-> benchmark")



@login_required(login_url='/user/login/')
def upload_results(request, benchmark_id):
  """
  Uploads the calculated files for a specific benchmark, given by its unique ID.

  :param request: The request.
  :param benchmark_id: The unique benchmark ID.
  """
  if request.method == 'POST':
    form = UploadResultsForm(request.POST, request.FILES, user=request.user)

    if form.is_valid():
      # Upload and save the file in a temporarily used directory
      prediction_filepath = handle_uploaded_file(request.FILES['file'])
      # Extract all, the groundtruth, source and prediction file

      benchmark_db = get_object_or_404(Benchmark, pk=request.POST.get('benchmark'))
      source_filepath = benchmark_db.download_file
      groundtruth_filepath = benchmark_db.groundtruth_file
      raw_filepath = benchmark_db.raw_file
      lang_code = benchmark_db.lang_code
      program = get_object_or_404(Program, pk=request.POST.get('program'))

      #
      extraction_path = '/data/' + ''.join(random.choice(string.ascii_lowercase) for i in range(16)) + '/'

      os.mkdir(extraction_path)

      print("Extract to: %s" % (extraction_path))

      shutil.copyfile(source_filepath, extraction_path + 'source.json')
      shutil.copyfile(groundtruth_filepath, extraction_path + 'groundtruth.json')
      shutil.copyfile(raw_filepath, extraction_path + 'raw.txt')
      shutil.copyfile(prediction_filepath, extraction_path + 'prediction.json')

      post_data = {
        "langCode": lang_code,
        "path": extraction_path
      }
      response = requests.post('http://evaluator:1338/api/v1/evaluate', json=post_data)

      print("response.text: %s" % (response.text))
      try:
        data = json.loads(response.text.replace("\\\"", "\"")[1:-1])
      except ValueError as e:
        data = json.loads(response.text)

      #print("data: %s" % (data))
      write_results_to_db(data, program, benchmark_db)

      # Write all information to the db
      print("Start alignment parsing ...")
      read_and_save_alignment_file(program, benchmark_db, extraction_path)

      # Remove the directory under /tmp
      delete_directory(extraction_path)

    #return render(request, 'workbench/benchmark.html', context)
    return benchmark(request, benchmark_id)

    if form.is_valid():
      pass
      # TODO(naetherm): Handle file content

  else:
    form = UploadResultsForm(user=request.user)
  context = {
    'form': form
  }
  return render(request, 'workbench/upload_results.html', context)

def result_format(request):
  """
  """
  return render(request, 'workbench/result_format.html', {})

def process_evaluation(request):
  return render(request, 'workbench/process_evaluation.html', {})

def initialize_internal_tables(request):
  """
  This will initialize the database information of groundtruth and source for all benchmarks that are currently
  available.
  """
  benchmarks = Benchmark.objects.order_by('benchmark_name')

  # Loop through all benchmarks
  for benchmark in benchmarks:
    # If there exist entries for the current benchmark in InternalSentenceInformation, delete them all
    InternalSentenceInformation.objects.filter(benchmark=benchmark).delete()

    groundtruth_filepath = benchmark.groundtruth_file
    source_filepath = benchmark.download_file

    # Read the content of both files
    source_content = None
    groundtruth_content = None
    with open(source_filepath, 'r') as fin:
      source_content = json.loads(fin.read())
    with open(groundtruth_filepath, 'r') as fin:
      groundtruth_content = json.loads(fin.read())

    # Build the source sentence representation [SID] -> "Sentence"
    #source_sentences, source_tokens = build_source_sentence_representation(source_content)
    #groundtruth_tokens, groundtruth_types, groundtruth_connections = build_groundtruth_sentence_representation(groundtruth_content)
    grt_results, num_articles, num_sentences = build_groundtruth_sentence_representation(groundtruth_content)
    source_results = build_source_sentence_representation(source_content, num_articles, num_sentences)

    #numArticles = len(source_results)

    for aidx, source in enumerate(source_results):
      for sidx in range(len(source.sentences)):
        # Get the sentence

        elems_ = []
        for idx, elem in enumerate(grt_results[aidx].connections[sidx]):
          elems_.append("{}->{}".format(idx, ",".join(str(e) for e in elem)))

        InternalSentenceInformation.objects.create(
          benchmark=benchmark,
          display=source.sentences[sidx],
          aidx=aidx,
          sidx=sidx,
          src_tokens=source.tokens[sidx],
          grt_tokens=grt_results[aidx].tokens[sidx],
          types= grt_results[aidx].types[sidx],
          connections="|".join(e for e in elems_)
        )


  context = {
    'benchmark_list': benchmarks,
    'user': request.user
  }

  return render(request, 'workbench/benchmarks.html', context)


def benchmark_populate_baseline(request, benchmark_id):
  """
  Download the data of a specific benchmark, given by the unique ID of the benchmark.

  :param request: The request.
  :param benchmark_id: The unique ID of the benchmark.
  """

  from os import listdir
  benchmark = get_object_or_404(Benchmark, pk=benchmark_id)
  programs = Program.objects.filter(is_baseline=True).order_by('program_name')

  groundtruth_filepath = benchmark.groundtruth_file
  raw_filepath = benchmark.raw_file
  lang_code = benchmark.lang_code

  ski_programs = ["LanguageTool", "Aspell", "HunSpell", "MaShape", "GrammarBot"]

  for program in programs:
    #if program.program_name == "GrammarBot" or program.program_name == "LanguageTool":
    #  continue
    if program.program_name in ski_programs:
      continue

    ##
    ##if program.program_name.lower() != 'xspell' and program.program_name.lower() != 'pyenchant':
    ##

    print("\n"*20)
    print("Populate for program: %s" % (program.program_name))
    extraction_path = '/data/' + ''.join(random.choice(string.ascii_lowercase) for i in range(16)) + '/'
    os.mkdir(extraction_path)
    print("extraction_path: %s" %(extraction_path))
    print(listdir(extraction_path))


    input_filepath = benchmark.download_file
    shutil.copyfile(input_filepath, extraction_path + 'source.json')
    shutil.copyfile(groundtruth_filepath, extraction_path + 'groundtruth.json')
    shutil.copyfile(raw_filepath, extraction_path + 'raw.txt')

    print("Start prediction phase ...")
    # Cleanup
    #for idx, l in enumerate(links):
    #  links[idx] = l.replace('\n', '')

    if os.path.exists(extraction_path + 'groundtruth.json'):
      source_content = ""

      with open(extraction_path + 'source.json', 'r') as fin:
        source_content = fin.read()

      prediction_content = predict_builtin(program.program_name, source_content, lang_code)

      if not os.path.exists(os.path.dirname(extraction_path + 'prediction.json')):
        os.makedirs(os.path.dirname(extraction_path + 'prediction.json'))
      with open(extraction_path + 'prediction.json', 'w', encoding='utf-8') as fout:
        fout.write(prediction_content)

    print(">> done!")

    post_data = {"langCode": lang_code, "path": extraction_path}
    print("Sent to responser : %s" %(post_data))
    response = requests.post('http://evaluator:1338/api/v1/evaluate', json=post_data)

    text_answer = response.text
    #print("text_answer: %s" % (text_answer))
    json_answer = response.json()
    #print("json_answer: %s" % (json_answer))
    #try:
    try:
      data = json.loads(response.text.replace("\\\"", "\"")[1:-1])

      #print("data: %s" % (data))
      write_results_to_db(data, program, benchmark)

      # Write all information to the db
      print("Start alignment parsing ...")
      read_and_save_alignment_file(program, benchmark, extraction_path)
    except:
      print("Ran into problems for Program {}".format(program.program_name))
      print("\tCorresponding prediction can be found under: {}".format(extraction_path))

    # Remove the directory under /tmp
    #delete_directory(extraction_path)


  results = Result.objects.filter(benchmark=benchmark_id)
  programs = Program.objects.filter()
  results = Result.objects.filter(benchmark=benchmark_id)
  sentences = receive_sentences_for_benchmark(benchmark_id)

  # Filter everything here

  context = {
    'benchmark': benchmark,
    'programs': programs,
    'results': results,
    'sentences': sentences,
    'user': request.user
  }

  NONE_TABLE = {}
  NON_WORD_TABLE = {}
  REAL_WORD_TABLE = {}
  SPLIT_TABLE = {}
  HYPHENATION_TABLE = {}
  COMPOUND_HYPHEN_TABLE = {}
  CONCATENATION_TABLE = {}
  CAPITALISATION_TABLE = {}
  REPEAT_TABLE = {}
  ARCHAIC_TABLE = {}
  PUNCTUATION_TABLE = {}
  MENTION_MISMATCH_TABLE = {}
  TENSE_TABLE = {}

  for program in programs:
    sub_categories = ErrorCategory.objects.filter(benchmark=benchmark_id, program=program.id)

    if sub_categories.count() > 0:

      #print("sub_categories[NONE]: %s" % (sub_categories.filter(name="NONE")[:1].get()))

      NONE_TABLE[program.program_name] = sub_categories.filter(name="NONE")[:1].get()
      NON_WORD_TABLE[program.program_name] = sub_categories.filter(name="NON_WORD")[:1].get()
      REAL_WORD_TABLE[program.program_name] = sub_categories.filter(name="REAL_WORD")[:1].get()
      SPLIT_TABLE[program.program_name] = sub_categories.filter(name="SPLIT")[:1].get()
      HYPHENATION_TABLE[program.program_name] = sub_categories.filter(name="HYPHENATION")[:1].get()
      COMPOUND_HYPHEN_TABLE[program.program_name] = sub_categories.filter(name="COMPOUND_HYPHEN")[:1].get()
      CONCATENATION_TABLE[program.program_name] = sub_categories.filter(name="CONCATENATION")[:1].get()
      CAPITALISATION_TABLE[program.program_name] = sub_categories.filter(name="CAPITALISATION")[:1].get()
      REPEAT_TABLE[program.program_name] = sub_categories.filter(name="REPEAT")[:1].get()
      ARCHAIC_TABLE[program.program_name] = sub_categories.filter(name="ARCHAIC")[:1].get()
      PUNCTUATION_TABLE[program.program_name] = sub_categories.filter(name="PUNCTUATION")[:1].get()
      MENTION_MISMATCH_TABLE[program.program_name] = sub_categories.filter(name="MENTION_MISMATCH")[:1].get()
      TENSE_TABLE[program.program_name] = sub_categories.filter(name="TENSE")[:1].get()

  context["NONE"] = NONE_TABLE
  context["NON_WORD"] = NON_WORD_TABLE
  context["REAL_WORD"] = REAL_WORD_TABLE
  context["SPLIT"] = SPLIT_TABLE
  context["HYPHENATION"] = HYPHENATION_TABLE
  context["COMPOUND_HYPHEN"] = COMPOUND_HYPHEN_TABLE
  context["CONCATENATION"] = CONCATENATION_TABLE
  context["CAPITALISATION"] = CAPITALISATION_TABLE
  context["REPEAT"] = REPEAT_TABLE
  context["ARCHAIC"] = ARCHAIC_TABLE
  context["PUNCTUATION"] = PUNCTUATION_TABLE
  context["MENTION_MISMATCH"] = MENTION_MISMATCH_TABLE
  context["TENSE"] = TENSE_TABLE

  return render(request, 'workbench/benchmark.html', context)

def populate_baselines(request):
  """
  """
  from os import listdir
  benchmarks = Benchmark.objects.order_by('benchmark_name')
  programs = Program.objects.filter(is_baseline=True).order_by('program_name')

  for benchmark in benchmarks:
    print("Populate for benchmark: %s" % (benchmark.benchmark_name))

    groundtruth_filepath = benchmark.groundtruth_file
    raw_filepath = benchmark.raw_file
    lang_code = benchmark.lang_code

    for program in programs:
      if program.program_name == "GrammarBot" or program.program_name == "LanguageTool":
        continue

      ##
      ##if program.program_name.lower() != 'xspell' and program.program_name.lower() != 'pyenchant':
      ##

      print("Populate for program: %s" % (program.program_name))
      extraction_path = '/data/' + ''.join(random.choice(string.ascii_lowercase) for i in range(16)) + '/'
      os.mkdir(extraction_path)
      print("extraction_path: %s" %(extraction_path))
      print(listdir(extraction_path))


      input_filepath = benchmark.download_file
      shutil.copyfile(input_filepath, extraction_path + 'source.json')
      shutil.copyfile(groundtruth_filepath, extraction_path + 'groundtruth.json')
      shutil.copyfile(raw_filepath, extraction_path + 'raw.txt')

      print("Start prediction phase ...")

      if os.path.exists(extraction_path + 'groundtruth.json'):
        #print("Evaluating '%s'" % (l))
        source_content = ""

        with open(extraction_path + 'source.json', 'r') as fin:
          source_content = fin.read()

        prediction_content = predict_builtin(program.program_name, source_content, lang_code)

        if not os.path.exists(os.path.dirname(extraction_path + 'prediction.json')):
          os.makedirs(os.path.dirname(extraction_path + 'prediction.json'))
        with open(extraction_path + 'prediction.json', 'w', encoding='utf-8') as fout:
          fout.write(prediction_content)
        #print(">> done")

      print(">> done!")

      post_data = {"langCode": lang_code, "path": extraction_path}
      print("Sent to responser : %s" %(post_data))
      response = requests.post('http://evaluator:1338/api/v1/evaluate', json=post_data)

      text_answer = response.text
      print("text_answer: %s" % (text_answer))
      #json_answer = response.json()
      #print("json_answer: %s" % (json_answer))
      #try:
      data = json.loads(response.text.replace("\\\"", "\"")[1:-1])

      #print("data: %s" % (data))
      write_results_to_db(data, program, benchmark)

      # Remove the directory under /tmp
      delete_directory(extraction_path)


  context = {
    'user': request.user,
    'benchmarks': benchmarks,
    'programs': programs
  }
  return render(request, 'workbench/populate_baselines.html', context)

def get_predictions_for_benchmark_and_program(request, benchmark_id, program_id):
  """
  Returns the prediction information for a specific benchmark and program.
  """

  from django.http import JsonResponse

  program = get_object_or_404(Program, pk=program_id)

  prediction_wrapper = {}
  p_predictions = receive_predictions_for_benchmark(benchmark_id, program)
  prediction_wrapper[program.program_name] = []
  for prediction in p_predictions:
    prediction_wrapper[program.program_name].append({'tokens': prediction.tokens, 'corrected': prediction.corrected, 'src': prediction.src_connections, 'grt': prediction.tgt_connections})


  return JsonResponse(prediction_wrapper, safe=True)

def get_predictions_for_benchmark(request, benchmark_id):
  """
  Returns the prediction information for a specific benchmark.
  """

  from django.http import JsonResponse

  programs = Program.objects.order_by('program_name')

  prediction_wrapper = {}
  for program in programs:
    p_predictions = receive_predictions_for_benchmark(benchmark_id, program)
    prediction_wrapper[program.program_name] = []
    for prediction in p_predictions:
      prediction_wrapper[program.program_name].append({'tokens': prediction.tokens, 'corrected': prediction.corrected, 'src': prediction.src_connections, 'grt': prediction.tgt_connections})


  return JsonResponse(prediction_wrapper, safe=True)



def get_sentences_and_prediction_for_idx(request):
  print("Received AJAX call with the following parameter of 'value': {}".format(request.GET.get('value', -1)))
  print("Fetch data for the benchmark with the ID: {}".format(request.GET.get('benchmark')))

  benchmark_id = request.GET.get('benchmark')
  sidx_to_fetch = request.GET.get('value')
  aidx_to_fetch = request.GET.get('aidx')
  benchmark = get_object_or_404(Benchmark, pk=benchmark_id)

  # Receive all program names from the database
  programs = Program.objects.order_by('program_name')
  # Receive the results for all programs of the given benchmark ID
  results = Result.objects.filter(benchmark=benchmark_id)

  sentence = receive_sentences_for_benchmark_new(benchmark, sidx_to_fetch, aidx_to_fetch)

  prediction_dummy = {}
  for program in programs:
    p_predictions = receive_predictions_for_benchmark_new(benchmark_id, program, sidx_to_fetch, aidx_to_fetch)
    prediction_dummy[program.program_name] = []
    for prediction in p_predictions:
      prediction_dummy[program.program_name].append({'tokens': prediction.tokens, 'corrected': prediction.corrected, 'src': prediction.src_connections, 'grt': prediction.tgt_connections})

  sentences_json = json.dumps((sentence[0].src_tokens, sentence[0].grt_tokens, sentence[0].types, sentence[0].connections))
  predictions_json = json.dumps(prediction_dummy)

  data = {
    'found_entries': True,
    'error_message': "Will look for the benchmark with ID '{}' and sentence ID {}".format(benchmark_id, sidx_to_fetch),
    'sentence': '{}'.format(sentences_json),
    'predictions': '{}'.format(predictions_json)
  }

  return JsonResponse(data)

def get_sentences_and_prediction_for_program(request):
  # The benchmark id
  benchmark_id = request.GET.get('benchmark')
  # The program id
  program_id = request.GET.get('program')

  sentences = receive_all_sentences_for_benchmark(benchmark_id)

  predictions = receive_all_predictions_for_benchmark(benchmark_id, program_id)



  sentences_dict = {}
  for sentence in sentences:
    sentences_dict['{}_{}'.format(sentence.aidx, sentence.sidx)] = (sentence.src_tokens, sentence.grt_tokens, sentence.types, sentence.connections)

  predictions_dict = {}
  for prediction in predictions:
    predictions_dict['{}_{}'.format(prediction.aid, prediction.sid)] = {
      'tokens': prediction.tokens,
      'corrected': prediction.corrected,
      'src': prediction.src_connections,
      'grt': prediction.tgt_connections
    }

  sentences_json = json.dumps(sentences_dict)
  predictions_json = json.dumps(predictions_dict)

  data = {
    'found_entries': True,
    'sentences': '{}'.format(sentences_json),
    'predictions': '{}'.format(predictions_json)
  }

  return JsonResponse(data)
