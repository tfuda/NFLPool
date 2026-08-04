import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import saveSelection from "@salesforce/apex/SelectionService.saveSelection";

const EMPTY_GAME = {};

export default class GameSelectionCard extends LightningElement {
  @api playerId;
  @api mode = "view";
  @api isAdmin = false;

  selectedTeamId;
  isSaving = false;

  _gameSelection;

  @api
  get gameSelection() {
    return this._gameSelection;
  }
  set gameSelection(value) {
    this._gameSelection = value;
    this.selectedTeamId = value ? value.selectedTeamId : null;
  }

  get game() {
    return this._gameSelection ? this._gameSelection.game : EMPTY_GAME;
  }

  get selection() {
    return this._gameSelection ? this._gameSelection.selection : null;
  }

  get gameNumber() {
    return this._gameSelection ? this._gameSelection.gameNumber : null;
  }

  get isLocked() {
    return this._gameSelection ? this._gameSelection.isLocked : false;
  }

  get isEditable() {
    return (
      !this.isSaving &&
      !!this.playerId &&
      (this.mode === "privileged-edit" ||
        (this.mode === "edit" && !this.isLocked))
    );
  }

  get buttonsDisabled() {
    return !this.isEditable;
  }

  get homeTeamId() {
    return this.game.Home_Team__c;
  }

  get visitingTeamId() {
    return this.game.Visiting_Team__c;
  }

  get homeTeamName() {
    return this.game.Home_Team__r ? this.game.Home_Team__r.Name : "";
  }

  get visitingTeamName() {
    return this.game.Visiting_Team__r ? this.game.Visiting_Team__r.Name : "";
  }

  get isHomeSelected() {
    return (
      this.selectedTeamId != null && this.selectedTeamId === this.homeTeamId
    );
  }

  get isVisitingSelected() {
    return (
      this.selectedTeamId != null && this.selectedTeamId === this.visitingTeamId
    );
  }

  get isFinal() {
    return this.game.Final__c === true;
  }

  get winner() {
    return this.game.Winner__c;
  }

  get isPush() {
    return this.isFinal && this.winner === "PUSH";
  }

  get isHomeWinner() {
    return this.isFinal && !this.isPush && this.winner === this.homeTeamName;
  }

  get isVisitingWinner() {
    return (
      this.isFinal && !this.isPush && this.winner === this.visitingTeamName
    );
  }

  get homeButtonClass() {
    return this.buildButtonClass(
      this.isHomeSelected,
      this.isHomeWinner,
      this.isVisitingWinner
    );
  }

  get visitingButtonClass() {
    return this.buildButtonClass(
      this.isVisitingSelected,
      this.isVisitingWinner,
      this.isHomeWinner
    );
  }

  buildButtonClass(isSelected, isWinner, isOpponentWinner) {
    let classes = "team-button";
    if (isSelected) {
      classes += " team-button_selected";
    }
    if (this.isFinal) {
      if (this.isPush) {
        classes += " team-button_push";
      } else if (isWinner) {
        classes += " team-button_winner";
      } else if (isOpponentWinner) {
        classes += " team-button_loser";
      }
    }
    if (!this.isEditable) {
      classes += " team-button_readonly";
    }
    return classes;
  }

  get hasSpread() {
    return this.game.Spread__c !== null && this.game.Spread__c !== undefined;
  }

  get homeSpreadDisplay() {
    return this.formatSpread(this.game.Spread__c);
  }

  get visitingSpreadDisplay() {
    return this.formatSpread(this.hasSpread ? -1 * this.game.Spread__c : null);
  }

  get homeLabel() {
    return this.hasSpread
      ? `${this.homeTeamName} (${this.homeSpreadDisplay})`
      : this.homeTeamName;
  }

  get visitingLabel() {
    return this.hasSpread
      ? `${this.visitingTeamName} (${this.visitingSpreadDisplay})`
      : this.visitingTeamName;
  }

  formatSpread(value) {
    if (value === null || value === undefined) {
      return "";
    }
    return (value >= 0 ? "+" : "") + value.toFixed(1);
  }

  get showScores() {
    return (
      this.game.Home_Score__c != null || this.game.Visiting_Score__c != null
    );
  }

  get homeScoreDisplay() {
    return this.game.Home_Score__c != null ? this.game.Home_Score__c : "-";
  }

  get visitingScoreDisplay() {
    return this.game.Visiting_Score__c != null
      ? this.game.Visiting_Score__c
      : "-";
  }

  get resultLabel() {
    if (!this.isFinal) {
      return "";
    }
    return this.isPush ? "Push" : `${this.winner} won`;
  }

  get showPoints() {
    return this.isFinal && this.selection && this.selection.Points__c != null;
  }

  get pointsLabel() {
    const points = this.selection.Points__c;
    return `${points} pt${points === 1 ? "" : "s"}`;
  }

  get cardAriaLabel() {
    return `Game ${this.gameNumber}: ${this.homeTeamName} versus ${this.visitingTeamName}`;
  }

  handleTeamClick(event) {
    if (!this.isEditable) {
      return;
    }
    const teamId = event.currentTarget.dataset.teamId;
    if (!teamId) {
      return;
    }
    // Clicking the already-selected team deselects it, clearing the pick for this game.
    const newTeamId = teamId === this.selectedTeamId ? null : teamId;
    this.saveTeamSelection(newTeamId);
  }

  async saveTeamSelection(teamId) {
    const previousTeamId = this.selectedTeamId;
    this.selectedTeamId = teamId;
    this.isSaving = true;
    try {
      await saveSelection({
        gameId: this.game.Id,
        playerId: this.playerId,
        selectedTeamId: teamId,
        isAdmin: this.isAdmin
      });
      this.dispatchEvent(
        new CustomEvent("selectionsaved", {
          detail: {
            gameNumber: this.gameNumber,
            gameId: this.game.Id,
            selectedTeamId: teamId
          }
        })
      );
    } catch (error) {
      this.selectedTeamId = previousTeamId;
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Unable to Save Selection",
          message: this.reduceError(error),
          variant: "error"
        })
      );
    } finally {
      this.isSaving = false;
    }
  }

  reduceError(error) {
    if (error && error.body && error.body.message) {
      return error.body.message;
    }
    if (error && error.message) {
      return error.message;
    }
    return "An unknown error occurred.";
  }
}
