
import os
from django.db import models
from django.http import HttpResponse

# Unfortunately we will need PostgreSQL specific fields here
from django.contrib.postgres.fields import ArrayField

#from users.models import User
from django.contrib.auth.models import User

class Program(models.Model):
  """
  """
  user = models.ForeignKey(User, on_delete=models.CASCADE)
  program_name = models.CharField(max_length=200)
  developer = models.CharField(max_length=200, blank=True)
  url = models.URLField(max_length=200, blank=True)
  is_baseline = models.BooleanField(default=False)

  def __str__(self):
    return f'{self.program_name}'

class Benchmark(models.Model):
  """
  """
  benchmark_name = models.CharField(max_length=200)
  download_file = models.FilePathField(path='/data/en_US/')
  groundtruth_file = models.FilePathField(path='/data/en_US/')
  raw_file = models.FilePathField(path='/data/en_US/')
  lang_code = models.CharField(max_length=10)

  def __str__(self):
    return f'{self.benchmark_name}'

class ErrorType(models.Model):
  name = models.CharField(max_length=200)
  benchmark = models.ForeignKey(Benchmark, on_delete=models.CASCADE)

  amount_errors = models.IntegerField(default=0)

class Result(models.Model):
  program = models.ForeignKey(Program, on_delete=models.CASCADE)
  benchmark = models.ForeignKey(Benchmark, on_delete=models.CASCADE)

  equalScore = models.FloatField(default=0)
  penalizedScore = models.FloatField(default=0)
  wordAccuracy = models.FloatField(default=0)
  sequenceAccuracy = models.FloatField(default=0)
  numSentences = models.FloatField(default=0)
  numErrorFreeSentences = models.FloatField(default=0)
  numCorrectSentences = models.FloatField(default=0)
  detectionAverageAccuracy = models.FloatField(default=0)
  detectionErrorRate = models.FloatField(default=0)
  correctionAverageAccuracy = models.FloatField(default=0)
  correctionErrorRate = models.FloatField(default=0)
  detectionPrecision = models.FloatField(default=0)
  detectionRecall = models.FloatField(default=0)
  detectionFScore = models.FloatField(default=0)
  correctionPrecision = models.FloatField(default=0)
  correctionRecall = models.FloatField(default=0)
  correctionFScore = models.FloatField(default=0)
  numTotalWords = models.FloatField(default=0)
  numErrors = models.IntegerField(default=0)
  detectedErrors = models.IntegerField(default=0)
  correctedErrors = models.IntegerField(default=0)
  suggestionAdequacy = models.FloatField(default=0)

class ErrorCategory(models.Model):
  """
  """
  result = models.ForeignKey(Result, on_delete=models.CASCADE)
  program = models.ForeignKey(Program, on_delete=models.CASCADE)
  benchmark = models.ForeignKey(Benchmark, on_delete=models.CASCADE)
  name = models.CharField(max_length=200)

  detectionPrecision = models.FloatField(default=0)
  detectionRecall = models.FloatField(default=0)
  detectionFScore = models.FloatField(default=0)
  correctionPrecision = models.FloatField(default=0)
  correctionRecall = models.FloatField(default=0)
  correctionFScore = models.FloatField(default=0)
  total = models.IntegerField(default=0)
  found = models.IntegerField(default=0)
  corrected = models.IntegerField(default=0)
  detection_tp = models.FloatField(default=0)
  detection_fp = models.FloatField(default=0)
  detection_tn = models.FloatField(default=0)
  detection_fn = models.FloatField(default=0)
  correction_tp = models.FloatField(default=0)
  correction_fp = models.FloatField(default=0)
  correction_tn = models.FloatField(default=0)
  correction_fn = models.FloatField(default=0)

  # TODO(naetherm): Add important results here

class InternalSentenceInformation(models.Model):
  """
  """
  # We need to know the benchmark we are assigned to
  benchmark = models.ForeignKey(Benchmark, on_delete=models.CASCADE)

  display = models.TextField()
  aidx = models.IntegerField(default=-1)
  sidx = models.IntegerField(default=-1)
  src_tokens = ArrayField(models.CharField(max_length=256), blank=True)
  grt_tokens = ArrayField(models.CharField(max_length=256), blank=True)
  types = ArrayField(models.CharField(max_length=256), blank=True)

  connections = models.TextField()

class PredictedSentenceInformation(models.Model):

  program = models.ForeignKey(Program, on_delete=models.CASCADE)
  benchmark = models.ForeignKey(Benchmark, on_delete=models.CASCADE)
  aid = models.IntegerField(default=-1)
  sid = models.IntegerField(default=-1)
  tokens = ArrayField(models.CharField(max_length=256), blank=True) # the predicted tokens
  corrected = ArrayField(models.CharField(max_length=256), blank=True)
  src_connections = models.TextField() # to source
  tgt_connections = models.TextField() # to groundtruth
