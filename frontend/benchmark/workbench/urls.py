

from django.urls import path

from django.conf.urls import url
from django.contrib.auth import views as auth_views

from . import views

app_name = 'workbench'
urlpatterns = [
  # /workbench/
  path('', views.index, name='index'),
  # /workbench/profile/
  path('profile/', views.profile, name='profile'),
  # /workbench/benchmarks/
  url(r'^benchs/', views.benchmarks, name='benchmarks'),
  # /workbench/benchmark/1
  path('bench/<int:benchmark_id>/', views.benchmark, name='benchmark'),
  # /workbench/benchmark/1/results/
  path('bench/results/<int:benchmark_id>/', views.results, name='results'),

  path('bench/result_format/', views.result_format, name='result_format'),

  path('bench/process_evaluation/', views.process_evaluation, name='process_evaluation'),

  path('bench/populate_baselines/', views.populate_baselines, name='populate_baselines'),

  path('bench/initialize_internal_tables/', views.initialize_internal_tables, name='initialize_internal_tables'),

  path('bench/add_result/<int:benchmark_id>', views.upload_results, name='upload_results'),

  path('bench/populate_baseline/<int:benchmark_id>', views.benchmark_populate_baseline, name='populate_baseline'),

  path('bench/download_data/<int:benchmark_id>', views.download_data, name='download_data'),

  #
  # AJAX Requests
  #
  url(r'^ajax/get_sentences_and_prediction_for_idx/$', views.get_sentences_and_prediction_for_idx, name='get_sentences_and_prediction_for_idx'),
  url(r'^ajax/get_sentences_and_prediction_for_program/$', views.get_sentences_and_prediction_for_program, name='get_sentences_and_prediction_for_program'),

  # /workbench/programs/
  url(r'^programs/', views.programs, name='programs'),
  # /workbench/program/1/
  path('program/<int:program_id>/', views.program, name='program'),
  # /workbench/add_program/
  path('program/add_program/', views.add_program, name='add_program')

]
