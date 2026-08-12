import { LightningElement, api } from "lwc";

const EMPTY_ROW = {};

export default class PlayerCard extends LightningElement {
  _row;
  @api
  get row() {
    return this._row;
  }
  set row(value) {
    this._row = value;
  }

  get player() {
    return this._row || EMPTY_ROW;
  }

  get cardAriaLabel() {
    return `Player: ${this.player.name}`;
  }

  handleViewClick() {
    this.dispatchEvent(new CustomEvent("select", { detail: { userId: this.player.userId } }));
  }

  handleActivateClick() {
    this.dispatchEvent(new CustomEvent("activate", { detail: { userId: this.player.userId } }));
  }

  handleDeactivateClick() {
    this.dispatchEvent(new CustomEvent("deactivate", { detail: { userId: this.player.userId } }));
  }
}
