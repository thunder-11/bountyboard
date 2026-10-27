export function paise(value, { min = 0n } = {}) {
  if (typeof value !== 'string' || !/^(0|[1-9]\d{0,9})(\.\d{1,2})?$/.test(value)) throw Object.assign(new Error('Use a nonnegative decimal string with at most two decimal places.'), { code: 'E_AMOUNT', status: 422 });
  const [whole, fraction = ''] = value.split('.');
  const amount = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
  if (amount < min || amount > 999999999999n) throw Object.assign(new Error('Amount is outside the allowed range.'), { code: 'E_AMOUNT', status: 422 });
  return amount;
}
export function decimal(amount) { return `${amount / 100n}.${String(amount % 100n).padStart(2, '0')}`; }
export function allocate(pool, weights) {
  if (!weights.length || weights.some(w => !Number.isInteger(w.basis_points) || w.basis_points <= 0) || weights.reduce((s,w) => s+w.basis_points,0) !== 10000) throw new Error('Weights must total 10000 basis points.');
  const rows = weights.map(w => ({ ...w, amount: pool * BigInt(w.basis_points) / 10000n, remainder: pool * BigInt(w.basis_points) % 10000n }));
  const extra = pool - rows.reduce((s,w) => s+w.amount,0n);
  const sorted = [...rows].sort((a,b) => a.remainder === b.remainder ? (BigInt(a.key) < BigInt(b.key) ? -1 : 1) : (a.remainder > b.remainder ? -1 : 1));
  for(let i=0; i<Number(extra); i++) sorted[i].amount++;
  return rows.map(({ remainder, ...w }) => w);
}
