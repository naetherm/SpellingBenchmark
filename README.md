# SpellingCorrectionBenchmark

Benchmark and Evaluation metrics for the task of spelling error detection and
correction.

## Usage

Note: You will need docker-compose installed on your machine.

### Quick Example

Just use docker-compose (keep in mind that we will need access to the university
network to receive the wikipedia dataset from ```/nfs/datasets/```, the creating of
the raw wikipedia data would take approx. a day):
```
docker-compose build web && docker-compose up web
```



The last parameter defines the type of benchmark (in size) that will be generated.

Note:
 - There are currently only four tools activated (the 'freely' available ones)
 - Further tools are available and implemented but they have restricted usage conditions (only 500 checks for TextRazor, etc.)

## Roadmap for version 2.0 of the benchmark

More error categories and further enhancements:

 - Better resolvement algorithms for the evaluator
 - Visualisation of the alignment for each sentence, for each tool
 - Multiple errors within given words. E.g. instead of an concatenation of the
   words "in the" to "inthe" make it possible to further distort this into e.g. "inteh"
   but still keep the information about being a concatenation of both words
   and that the second word within that concatenation is a non_word
 - Concatenations
 - Distinguish between missing hyphenation and hyphen-error?
 - Grammar errors:
   - Subject-Verb Agreement Errors
   - Missing Commas (e.g. after introductory element, in compound sentence, comma splice, etc.)
   - Misusing of Apostrophe
   - Misplaced/Dangling Modifiers
