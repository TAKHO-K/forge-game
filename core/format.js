// 큰 숫자 축약 표기 (data/balance.js NUMBER_ABBREVIATION 참고) - 화면 표시용 문자열만 만들고
// 내부 계산에는 절대 쓰지 않는다. 모든 fillText/textContent 조립 지점에서 원본 숫자 대신 이 함수의
// 결과를 쓰는 것이 규칙.

// stepIndex(0=A, 1=B, ...)를 알파벳 표기로 변환 - 스프레드시트 열 이름과 같은 bijective 진법이라
// letters 길이(26)를 넘어가도 AA, AB, ... 로 끝없이 이어진다(0을 표현하는 글자가 없어 나머지 계산 전에 1을 뺀다).
function numberAbbreviationLetter(stepIndex) {
  const letters = NUMBER_ABBREVIATION.letters;
  let n = stepIndex + 1;
  let label = "";
  while (n > 0) {
    n -= 1;
    label = letters[n % letters.length] + label;
    n = Math.floor(n / letters.length);
  }
  return label;
}

function formatAbbreviatedNumber(value) {
  const n = Math.floor(value);
  if (n < NUMBER_ABBREVIATION.minValue) return n.toLocaleString();

  const step = NUMBER_ABBREVIATION.step;
  let scaled = n;
  let stepIndex = -1;
  while (scaled >= step) {
    scaled /= step;
    stepIndex++;
  }

  const factor = Math.pow(10, NUMBER_ABBREVIATION.decimals);
  const truncated = Math.floor(scaled * factor) / factor;
  const text = Number.isInteger(truncated) ? String(truncated) : truncated.toFixed(NUMBER_ABBREVIATION.decimals);
  return `${text}${numberAbbreviationLetter(stepIndex)}`;
}
