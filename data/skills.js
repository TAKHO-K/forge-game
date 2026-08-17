// 스킬 정의 (효과 조각의 조합, PRD 4.3) - 스킬 전용 함수를 만들지 않고
// core/skills.js의 범용 핸들러가 여기 effects 배열을 해석한다.
// v1은 Q만 채운다. E는 다음 단계에서 조각 타입을 추가해 붙인다.
const SKILLS = {
  healer: {
    Q: {
      name: "치유", cooldown: 25,
      effects: [
        { type: "heal", baseAmount: 3, scaleWithHealPower: true, critDoubles: true }
      ]
    }
  }
};
