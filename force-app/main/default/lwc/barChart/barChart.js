import { LightningElement, api } from "lwc";

const DEFAULT_COLOR = "#0b5cab";

export default class BarChart extends LightningElement {
  @api title;
  @api rows;
  @api max;
  @api color = DEFAULT_COLOR;
  @api formatMode = "points";

  get hasRows() {
    return this.rows && this.rows.length > 0;
  }

  get caption() {
    if (this.formatMode === "points" && this.max != null) {
      return `Total points available: ${Number(this.max).toFixed(1)}`;
    }
    return "";
  }

  get displayRows() {
    const max = Number(this.max) || 0;
    return (this.rows || []).map((row) => {
      const pct = max ? Math.min(100, Math.max(0, (row.value / max) * 100)) : 0;
      const valueLabel = this.formatValue(row.value);
      return {
        label: row.label,
        valueLabel,
        titleAttr: `${row.label}: ${valueLabel}`,
        fillStyle: `width: ${pct}%; background-color: ${this.color};`
      };
    });
  }

  formatValue(value) {
    if (value == null) {
      return "";
    }
    return this.formatMode === "percentage"
      ? `${(value * 100).toFixed(1)}%`
      : Number(value).toFixed(1);
  }
}
