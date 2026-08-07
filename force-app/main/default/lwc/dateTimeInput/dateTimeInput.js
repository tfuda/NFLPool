import { LightningElement, api } from "lwc";

export default class DateTimeInput extends LightningElement {
  @api label = "Start Time";
  @api variant;

  _value;
  displayValue = "";
  hasError = false;

  @api
  get value() {
    return this._value;
  }
  set value(isoString) {
    this._value = isoString;
    this.displayValue = this.formatForDisplay(isoString);
    this.hasError = false;
  }

  formatForDisplay(isoString) {
    if (!isoString) {
      return "";
    }
    const date = new Date(isoString);
    if (Number.isNaN(date.getTime())) {
      return "";
    }
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const year = date.getFullYear();
    let hours = date.getHours();
    const minutes = String(date.getMinutes()).padStart(2, "0");
    const ampm = hours >= 12 ? "PM" : "AM";
    hours %= 12;
    hours = hours === 0 ? 12 : hours;
    return `${month}/${day}/${year} ${hours}:${minutes} ${ampm}`;
  }

  // lightning-input fires its own "change" event on every keystroke for
  // text inputs, and that event bubbles straight through this component's
  // shadow boundary to whatever is listening for "change" on the parent's
  // <c-date-time-input> element -- which expects OUR parsed/committed
  // "change" event from commitValue(), not the raw per-keystroke one.
  // Swallow it here so only our own dispatched event ever escapes.
  handleInnerChange(event) {
    event.stopPropagation();
  }

  // Deliberately don't write to any reactive/tracked property while the
  // user is typing -- re-rendering the bound `value` mid-edit fights the
  // native input's own cursor/typing state. Read the live DOM value
  // directly and commit only on blur/"now".
  handleBlur() {
    const input = this.template.querySelector(".date-time-input__field");
    this.commitValue(input ? input.value : "");
  }

  handleNowClick() {
    this.commitValue(this.formatForDisplay(new Date().toISOString()));
  }

  commitValue(text) {
    const trimmed = (text || "").trim();
    if (!trimmed) {
      this.hasError = false;
      this._value = null;
      this.displayValue = "";
      this.dispatchChange(null);
      return;
    }
    const parsed = new Date(trimmed);
    if (Number.isNaN(parsed.getTime())) {
      this.hasError = true;
      return;
    }
    this.hasError = false;
    this._value = parsed.toISOString();
    this.displayValue = this.formatForDisplay(this._value);
    this.dispatchChange(this._value);
  }

  dispatchChange(value) {
    this.dispatchEvent(new CustomEvent("change", { detail: { value } }));
  }
}
