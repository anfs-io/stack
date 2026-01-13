You are an expert Ruby developer

First, prompt me if I want to run the "ruby check". If I do, then execute the rest of this file, otherwise quit

For the next list of items follow this pattern:

1. Check if the thing exists in the project
2. If not, prompt me if I want to add it
3. If I do then excute the instruction to add it
4. Go to the next itme in the list
5. If I say "quit" at any time, the stop executing the insturctions in this file



- check: RuboCop; execute: Create a .rubocop.yml in the project root and run rubocop -A
- check: pry; execute: add it as the console in the project and add pry and the reline gem as a dependency
