import { LightningElement, api } from "lwc";

const EMPTY_ROW = {};
const LOOKUP_FIELDS = new Set(["Home_Team__c", "Visiting_Team__c"]);

export default class GameEditCard extends LightningElement {
  @api teamOptions = [];

  _row;
  @api
  get row() {
    return this._row;
  }
  set row(value) {
    this._row = value;
  }

  get game() {
    return this._row ? this._row.game : EMPTY_ROW;
  }

  get gameNumber() {
    return this._row ? this._row.gameNumber : null;
  }

  get isLocked() {
    return this._row ? this._row.isLocked : false;
  }

  get cardAriaLabel() {
    return `Game ${this.gameNumber}: ${this.homeTeamName} versus ${this.visitingTeamName}`;
  }

  get homeTeamName() {
    return this._row ? this._row.homeTeamName : "";
  }

  get visitingTeamName() {
    return this._row ? this._row.visitingTeamName : "";
  }

  // A <select value={...}> binding is unreliable when its <option>
  // children come from for:each -- the value gets applied before the
  // options exist in the DOM. Compute the selected option explicitly
  // instead and bind `selected` on each <option>.
  buildTeamOptions(selectedId) {
    const normalizedSelected = selectedId || "";
    return (this.teamOptions || []).map((option) => ({
      value: option.value,
      label: option.label,
      selected: option.value === normalizedSelected
    }));
  }

  get homeTeamOptions() {
    return this.buildTeamOptions(this.game.Home_Team__c);
  }

  get visitingTeamOptions() {
    return this.buildTeamOptions(this.game.Visiting_Team__c);
  }

  get isStartTimeEditable() {
    return this._row ? this._row.isStartTimeEditable : false;
  }

  get isHomeTeamEditable() {
    return this._row ? this._row.isHomeTeamEditable : false;
  }

  get isVisitingTeamEditable() {
    return this._row ? this._row.isVisitingTeamEditable : false;
  }

  get isSpreadEditable() {
    return this._row ? this._row.isSpreadEditable : false;
  }

  get isScoreEditable() {
    return this._row ? this._row.isScoreEditable : false;
  }

  get isFinalDisabled() {
    return this._row ? this._row.isFinalDisabled : true;
  }

  get showWinner() {
    return this._row ? this._row.showWinner : false;
  }

  get isDeleteVisible() {
    return this._row ? this._row.isDeleteVisible : false;
  }

  get isDeleteDisabled() {
    return this._row ? this._row.isDeleteDisabled : false;
  }

  handleFieldChange(event) {
    const field = event.currentTarget.dataset.field;
    // Home/Visiting Team use a native <select> (for native type-ahead
    // cycling, which lightning-combobox doesn't support), so it fires a
    // plain DOM change event with no .detail -- read .target.value instead.
    const detail = LOOKUP_FIELDS.has(field)
      ? { value: event.target.value }
      : event.detail;
    this.dispatchEvent(
      new CustomEvent("fieldchange", {
        detail: { index: this._row.index, field, detail }
      })
    );
  }

  handleDeleteClick() {
    this.dispatchEvent(
      new CustomEvent("deletegame", { detail: { index: this._row.index } })
    );
  }
}
