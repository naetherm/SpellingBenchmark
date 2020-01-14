
from django import forms

from .models import Benchmark, Program

class AddProgramForm(forms.ModelForm):
  """
  """

  class Meta:
    model = Program
    fields = ('program_name', 'developer', 'url')

  #name = forms.CharField(max_length=200)
  #developer = forms.CharField(max_length=200, required=False)
  #url = forms.URLField(label='Your website', required=False)

  def save(self, commit=True, user=None):

    program = super(AddProgramForm, self).save(commit=False)
    program.user = user
    if commit:
      program.save()
    return program

class UploadResultsForm(forms.Form):
  """
  """
  benchmark = forms.ModelChoiceField(queryset=Benchmark.objects, empty_label=None)
  program = forms.ModelChoiceField(queryset=Program.objects, empty_label=None)
  file = forms.FileField()

  def __init__(self, *args, **kwargs):
    self.user = kwargs.pop('user',None)
    super(UploadResultsForm, self).__init__(*args, **kwargs)

    self.fields['program'] = forms.ModelChoiceField(queryset=Program.objects.filter(user=self.user), empty_label=None)
