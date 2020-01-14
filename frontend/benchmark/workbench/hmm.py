

# @author Ashish Tamrakar
# @Date 2016-03-11
# Program to training the HMM model and then using Viterbi to find the corrected word
# Python v2.7.10

import regex as re
import sys
import random
import math
import string
import numpy as np


class Viterbi:
  def __init__(self, probEmission, probTransition, testSet):
    self.delta = []
    self.states = list(string.ascii_lowercase + string.ascii_uppercase)
    self.symbols = list(string.ascii_lowercase + string.ascii_uppercase)
    self.corruptedTestSet = testSet
    self.emissionProbabilities = probEmission
    self.transitionProbabilities = probTransition
    self.initialProbabilities = float(1)/len(self.states)      # Same initial probabilities for every states

    self.FN = 0
    self.TP = 0
    self.totalWords = 0
    self.FP = 0

  def calculateInitialDelta(self, symbolChar):
    self.delta = []
    for i in range(0, len(self.states)):
      init = self.initialProbabilities
      emission = self.emissionProbabilities[i][self.symbols.index(symbolChar)]
      self.delta.append(math.log(emission) + math.log(init))

  def calculateDelta(self, symChar):
    backTrack = [None] * len(self.states)
    deltaTemp = [None] * len(self.states)
    for j in range(0, len(self.states)):
      maxValue = None
      for i in range(0, len(self.states)):
        transition = self.transitionProbabilities[i][j]
        mul = self.delta[i] + math.log(transition)
        if (maxValue is None or mul > maxValue):
          maxValue = mul
          backTrack[j] = self.symbols[i]
      deltaCalc = maxValue + math.log((self.emissionProbabilities[j][self.symbols.index(symChar)]))
      deltaTemp[j] = deltaCalc
    self.delta = deltaTemp
    return backTrack

  def correctedWord(self, backTrack):
    temp = self.delta.index(max(self.delta))
    word = [self.symbols[temp]]
    if (backTrack):
      for l in backTrack:
        word.append(l[temp])
        temp = self.states.index(l[temp])
      word.reverse()
    return ''.join(word)

  def process(self, testSet):
    # TP: wrong-->correct
    # FN: wrong-->wrong
    # TP: correct-->wrong
    #Precision = TP/(TP + FN)
    #Recall = TP/(TP + FP)

    #testSet = [x for x in testSet if x.isalpha()]
    result = []
    counter = 0
    for word in testSet:
      # print "==============================="
      # print "Actual:", testSet[counter]
      # print "Corrupted:", word
      backtrack = []
      for i in range(0, len(word)):
        symChar = word[i]
        if (i is 0):
          self.calculateInitialDelta(symChar)
        else:
          backtrack.insert(0, self.calculateDelta(symChar))

      result.append(self.correctedWord(backtrack))

    return result


class SpellingCorrection:

  doc = None
  trainingSet = []
  testSet = []
  corruptedTrainingSet = []
  corruptedTestSet = []

  def __init__(self):
    self.wordsList = []
    self.alphabets = string.ascii_lowercase + string.ascii_uppercase
    self.Aij = None#np.zeros((len(self.length), len(self.length)), dtype=int)
    self.Eis = None#np.zeros((len(self.length), len(self.length)), dtype=int)
    self.probAij = None#np.zeros((len(self.length), len(self.length)), dtype=float)
    self.probEis = None#np.zeros((len(self.length), len(self.length)), dtype=float)
    self.length = 0
    self.surroundingChars = {}


  def readFromFile(self, fileName ='./data/unabom.txt'):
    """
    Read dataset from the filename.
    """
    file = open(fileName, "r")
    self.doc = file.read()

  def splitToWords(self):
    """
    Splits the words from the text and inserts into wordList
    """
    self.wordsList = re.findall(r'\w+', self.doc)

  def splitDocument(self):
    """
    Splits the document into training set (80%) and test set (20%)
    """
    # self.readFromFile('basicTest.txt')
    # self.readFromFile('testdata.txt')
    self.readFromFile()
    self.splitToWords()
    indexSplit = int(0.8 * len(self.wordsList))
    # splits into training set and test set
    self.trainingSet = [x.strip() for x in self.wordsList[:indexSplit]]
    self.testSet = [x.strip() for x in self.wordsList[indexSplit:]]
    # print self.testSet


  def corruptText(self, wordList, isTrainingSet = False):
    """
    Corrupts the text and updates the emission count and transition count if it is training set
    """
    corruptedlist = []
    self.surroundingChars = {
      'a': ['q', 'w', 's', 'x', 'z'],
      'b': ['f', 'g', 'h', 'n', 'v'],
      'c': ['x', 's', 'd', 'f', 'v'],
      'd': ['w', 'e', 'r', 's', 'f', 'x', 'c', 'v'],
      'e': ['w', 'r', 's', 'd', 'f'],
      'f': ['e', 'r', 't', 'd', 'g', 'c', 'v', 'b'],
      'g': ['r', 't', 'y', 'f', 'h', 'v', 'b', 'n'],
      'h': ['t', 'y', 'u', 'g', 'j', 'b', 'n', 'm'],
      'i': ['u', 'o', 'j', 'k', 'l'],
      'j': ['y', 'u', 'i', 'h', 'k', 'n', 'm'],
      'k': ['u', 'i', 'o', 'j', 'l', 'm'],
      'l': ['i', 'o', 'p', 'k'],
      'm': ['n', 'h', 'j', 'k'],
      'n': ['b', 'g', 'h', 'j', 'm'],
      'o': ['i', 'k', 'l', 'p'],
      'p': ['o', 'l'],
      'q': ['a', 's', 'w'],
      'r': ['e', 'd', 'f', 'g', 't'],
      's': ['q', 'w', 'e', 'a', 'd', 'z', 'x', 'c'],
      't': ['r', 'y', 'f', 'g', 'h'],
      'u': ['y', 'i', 'h', 'j', 'k'],
      'v': ['d', 'f', 'g', 'c', 'b'],
      'w': ['q', 'e', 'a', 's', 'd'],
      'x': ['a', 's', 'd', 'z', 'c'],
      'y': ['t', 'u', 'g', 'h', 'j'],
      'z': ['a', 's', 'x'],
      'A': ['Q', 'W', 'S', 'X', 'Z'],
      'B': ['F', 'G', 'H', 'N', 'V'],
      'C': ['X', 'S', 'D', 'F', 'V'],
      'D': ['W', 'E', 'R', 'S', 'F', 'X', 'C', 'V'],
      'E': ['W', 'R', 'S', 'D', 'F'],
      'F': ['E', 'R', 'T', 'D', 'G', 'C', 'V', 'B'],
      'G': ['R', 'T', 'Y', 'F', 'H', 'V', 'B', 'N'],
      'H': ['T', 'Y', 'U', 'G', 'J', 'B', 'N', 'M'],
      'I': ['U', 'O', 'J', 'K', 'L'],
      'J': ['Y', 'U', 'I', 'H', 'K', 'N', 'M'],
      'K': ['U', 'I', 'O', 'J', 'L', 'M'],
      'L': ['I', 'O', 'P', 'K'],
      'M': ['N', 'H', 'J', 'K'],
      'N': ['B', 'G', 'H', 'J', 'M'],
      'O': ['I', 'K', 'L', 'P'],
      'P': ['O', 'L'],
      'Q': ['A', 'S', 'W'],
      'R': ['E', 'D', 'F', 'G', 'T'],
      'S': ['Q', 'W', 'E', 'A', 'D', 'Z', 'X', 'C'],
      'T': ['R', 'Y', 'F', 'G', 'H'],
      'U': ['Y', 'I', 'H', 'J', 'K'],
      'V': ['D', 'F', 'G', 'C', 'B'],
      'W': ['Q', 'E', 'A', 'S', 'D'],
      'X': ['A', 'S', 'D', 'Z', 'C'],
      'Y': ['T', 'U', 'G', 'H', 'J'],
      'Z': ['A', 'S', 'X'],
      '0': ['9'],
      '9': ['8', '0'],
      '8': ['7', '9'],
      '7': ['6', '8'],
      '6': ['5', '7'],
      '5': ['4', '6'],
      '4': ['3', '5'],
      '3': ['2', '4'],
      '2': ['1', '3'],
      '1': ['2'],
      '"': [':', '?', '{', '}'],
      '<': ['m', '>', 'L', 'K'],
      '>': ['<', 'L', ':'],
      ',': ['m', 'k', 'l', '.'],
      '.': [',', 'l', ';', '/'],
      ';': ['l', 'p', '[', ']', '`'],
      '[': ['p', ';', '`'],
      ']': ['[', '`'],
      '?': ['>', '"', ':'],
      '!': ['@', '~'],
      '~': ['!'],
      '\\': [']'],
      '@': ['!', '#'],
      '#': ['@', '$'],
      '$': ['#', '%'],
      '^': ['$', '&'],
      '&': ['^', '*'],
      '*': ['&', '('],
      '(': ['*', ')'],
      ')': ['(', '_'],
      '_': [')', '+'],
      '+': ['_'],
      '-': ['0', '='],
      '=': ['-']
    }
    self.length = len(self.alphabets)
    self.Aij = np.zeros((self.length, self.length), dtype=int)
    self.Eis = np.zeros((self.length, self.length), dtype=int)
    self.probAij = np.zeros((self.length, self.length), dtype=float)
    self.probEis = np.zeros((self.length, self.length), dtype=float)
    for word in wordList:
      tempWord = ""
      if (word.isalpha()):
        for i in range(0, len(word)):
          r = random.uniform(0, 1)
          # To corrupt the letter if the random value generated is less than threshold
          if (r < 0.2):
            tempWord += random.choice(self.surroundingChars[word[i]] if word[i] in self.surroundingChars else [''])
            # tempWord += random.choice(string.ascii_lowercase)
          else:
            tempWord += word[i]
          # updates the count for emission probability and transition probability
          if (isTrainingSet):
            self.incrEmissionCount(word[i], tempWord[i])
            # Keep track of the transitions from state i to state j
            if (i is not len(word)-1):
              # count the transition from state i to state j
              self.incrTransitionCount(word[i], word[i+1])

          corruptedlist.append(tempWord.strip())

    return corruptedlist

  def incrTransitionCount(self, stateI, stateJ):
    if (stateJ in self.surroundingChars and stateI in self.surroundingChars):
      self.Aij[list(self.surroundingChars).index(stateI)][list(self.surroundingChars).index(stateJ)] += 1

  def incrEmissionCount(self, currentSymbol, symbolS):
    if (symbolS in self.surroundingChars and currentSymbol in self.surroundingChars):
      self.Eis[list(self.surroundingChars).index(currentSymbol)][list(self.surroundingChars).index(symbolS)] += 1

  def probabilityAij(self):
    for i in range(0, self.length):
      # Smoothing (helps to add the transition from the state where there is no count in training set
      if (0 in self.Aij[i]):
        self.Aij[i] = [x+1 for x in self.Aij[i]]
      sum = self.Aij[i].sum()
      # print self.Aij[i], self.alphabets[i], sum
      for j in range(0, self.length):
        self.probAij[i][j] = float(self.Aij[i][j]) / sum

  def probabilityEmission(self):
    for i in range(0, self.length):
      # Smoothing (helps to add the transition from the state where there is no count in training set
      if (0 in self.Eis[i]):
        self.Eis[i] = [x+1 for x in self.Eis[i]]
      sum = self.Eis[i].sum()
      # print self.alphabets[i], sum
      for j in range(0, self.length):
        self.probEis[i][j] = float(self.Eis[i][j]) / sum

  def getEmissionProbabilities(self):
    return self.probEis

  def getTransitionProbabilities(self):
    return self.probAij

  def trainHMModel(self):
    self.splitDocument()
    # Corrupt the text splited for training set and test set
    self.corruptedTrainingSet = self.corruptText(self.trainingSet, True)
    # Calculate the probability for transition from state i to state j
    self.corruptedTestSet = self.corruptText(self.testSet, False)

    self.probabilityAij()
    self.probabilityEmission()
