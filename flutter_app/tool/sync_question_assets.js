'use strict';

const fs = require('fs');
const path = require('path');
const { PROBLEMS, DEBUGGING_QUESTIONS } = require('../../js/questions');

const dataDirectory = path.join(__dirname, '..', 'assets', 'data');
fs.mkdirSync(dataDirectory, { recursive: true });

const problems = PROBLEMS.map(({ id, title, diff, tags, acc, desc, ex, cons, tc, starterCode }) => ({
  id,
  title,
  difficulty: diff,
  tags,
  acceptanceRatePercent: acc,
  description: desc,
  examples: ex,
  constraints: cons,
  testCases: tc,
  starterCode
}));

fs.writeFileSync(path.join(dataDirectory, 'problems.json'), `${JSON.stringify(problems, null, 2)}\n`);
fs.writeFileSync(
  path.join(dataDirectory, 'debugging_questions.json'),
  `${JSON.stringify(DEBUGGING_QUESTIONS, null, 2)}\n`
);

console.log(`Generated ${problems.length} problems and ${DEBUGGING_QUESTIONS.length} debugging questions.`);