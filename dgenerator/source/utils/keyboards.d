// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.utils.keyboards;

/*
 * A collection of different keyboard layouts
 */

import std.algorithm;
import std.string;

bool isQwertz(string lang_code) {
  return (["de_DE"].canFind(lang_code));
}

bool isQwerty(string lang_code) {
  return (["en_US"].canFind(lang_code));
}


static const wchar[][] qwertyKeyboardArray = [['`','1','2','3','4','5','6','7','8','9','0','-','='],
  ['q','w','e','r','t','y','u','i','o','p','[',']','\\'],
  ['a','s','d','f','g','h','j','k','l',';','\''],
  ['z','x','c','v','b','n','m',',','.','/'],
  [' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ']
];

static const wchar[][] qwertyShiftedKeyboardArray = [
  ['~', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '+'],
  ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '|'],
  ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"'],
  ['Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?'],
  [' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ']
];
static const wchar[][] qwertzKeyboardArray = [
  ['^','1','2','3','4','5','6','7','8','9','0','ß','´'],
  ['q','w','e','r','t','z','u','i','o','p','ü','+','\\'],
  ['a','s','d','f','g','h','j','k','l','ö','ä'],
  ['y','x','c','v','b','n','m',',','.','-'],
  [' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ']
];
static const wchar[][] qwertzShiftedKeyboardArray = [
  ['°', '!', '\"', '§', '$', '%', '&', '/', '(', ')', '=', '?', '`'],
  ['Q', 'W', 'E', 'R', 'T', 'Z', 'U', 'I', 'O', 'P', 'Ü', '*', '|'],
  ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ö', 'Ä'],
  ['Y', 'X', 'C', 'V', 'B', 'N', 'M', ';', ':', '_'],
  [' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ']
];
static const wchar[] compareDummy = ['`','1','2','3','4','5','6','7','8','9','0','-','=',
  'q','w','e','r','t','y','u','i','o','p','[',']','\\',
  'a','s','d','f','g','h','j','k','l',';','\'',
  'z','x','c','v','b','n','m',',','.','/',
  ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
  '~', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '+',
  'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '|',
  'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"',
  'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?',
  ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '];
