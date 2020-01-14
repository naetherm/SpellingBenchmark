
import regex as re

def call_regex(src):
  '''
  One place for the regex.
  '''
  #return re.findall(r"(?:[\w]+(?:[-]+[\w]+)+)|(?:[\w]+(?:[']+[\w])+)|\b[_]|(?:[_]*[\w]+(?=_\b))|\w+|[^\w\s]", src, re.UNICODE)
  tokens = re.findall(r"(?:\d+,\d+)|(?:[\w'\u0080-\u9999]+(?:[-]+[\w'\u0080-\u9999]+)+)|(?:[\w\u0080-\u9999]+(?:[']+[\w\u0080-\u9999]+)+)|\b[_]|(?:[_]*[\w\u0080-\u9999]+(?=_\b))|(?:[\w\u0080-\u9999]+)|[^\w\s\p{Z}]", src, re.UNICODE)

  spaces = []
  char_counter = 0
  for t in tokens:
    char_counter += len(t)
    if char_counter >= len(src):
      spaces.append(False)
    else:
      if src[char_counter] == ' ':
        spaces.append(True)
        char_counter += 1
      else:
        spaces.append(False)

  return tokens, spaces


if __name__ == '__main__':
  test = "This is, a rather tiny, test sentence."

  tokens, spaces = call_regex(test)

  assert(len(tokens) == 10)
  assert(len(spaces) == 10)
  assert(tokens[0] == "This")
  assert(tokens[1] == "is")
  assert(tokens[2] == ",")
  assert(tokens[3] == "a")
  assert(tokens[4] == "rather")
  assert(tokens[5] == "tiny")
  assert(tokens[6] == ",")
  assert(tokens[7] == "test")
  assert(tokens[8] == "sentence")
  assert(tokens[9] == ".")
  assert(spaces[0] == True)
  assert(spaces[1] == False)
  assert(spaces[2] == True)
  assert(spaces[3] == True)
  assert(spaces[4] == True)
  assert(spaces[5] == False)
  assert(spaces[6] == True)
  assert(spaces[7] == True)
  assert(spaces[8] == False)
  assert(spaces[9] == False)
