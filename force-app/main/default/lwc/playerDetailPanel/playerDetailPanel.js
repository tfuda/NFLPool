import { LightningElement, api } from "lwc";

const MODE_VIEW = "view";
const MODE_EDIT = "edit";
const MODE_NEW = "new";

const EDITABLE_USR_FIELDS = [
  "FirstName",
  "LastName",
  "Username",
  "CommunityNickname",
  "Email",
  "Phone",
  "Street",
  "City",
  "State",
  "PostalCode",
  "ProfileId",
  "IsActive"
];

export default class PlayerDetailPanel extends LightningElement {
  @api mode;
  @api profileOptions = [];
  @api isLoading = false;
  @api isSaving = false;
  @api errorMessage;

  draftUsr = {};
  draftPayments = [];
  editingPaymentIndex = null;
  _baselineUsr = {};

  _playerDetail;
  // Rebuild the local editable copies whenever the parent hands us a new
  // playerDetail (initial load, after a successful save, or after switching
  // to a different player) -- not on every keystroke, since edits are held
  // locally here and only sent up on Save. _baselineUsr is captured at the
  // same time and never mutated afterward, so isDirty can tell a real edit
  // apart from just being in edit/new mode with nothing changed yet.
  @api
  get playerDetail() {
    return this._playerDetail;
  }
  set playerDetail(value) {
    this._playerDetail = value;
    this.draftUsr = value && value.usr ? { ...value.usr } : {};
    this._baselineUsr = { ...this.draftUsr };
    this.draftPayments = ((value && value.payments) || []).map((payment, index) => ({
      index,
      payment: { ...payment },
      rowMode: "view"
    }));
    this.editingPaymentIndex = null;
  }

  get isDirty() {
    if (this.editingPaymentIndex !== null) {
      return true;
    }
    return EDITABLE_USR_FIELDS.some(
      (field) => (this.draftUsr[field] || "") !== (this._baselineUsr[field] || "")
    );
  }

  confirmDiscardIfDirty() {
    if (!this.isDirty) {
      return true;
    }
    // eslint-disable-next-line no-alert
    return window.confirm(
      "WARNING! You have unsaved changes. Clicking OK will discard them. Click Cancel to keep editing."
    );
  }

  get isView() {
    return this.mode === MODE_VIEW;
  }

  get isEdit() {
    return this.mode === MODE_EDIT;
  }

  get isNew() {
    return this.mode === MODE_NEW;
  }

  get isEditOrNew() {
    return this.isEdit || this.isNew;
  }

  get showActiveField() {
    return this.isEdit;
  }

  get profileName() {
    return (this.draftUsr && this.draftUsr.Profile && this.draftUsr.Profile.Name) || "";
  }

  get panelTitle() {
    if (this.isNew) {
      return "New Player";
    }
    return (this.draftUsr && this.draftUsr.Name) || "Player Details";
  }

  get hasPlayerRecord() {
    return !!(this.playerDetail && this.playerDetail.player);
  }

  get playerRecordName() {
    return this.hasPlayerRecord ? this.playerDetail.player.Name : "";
  }

  get playerRecordUrl() {
    return this.hasPlayerRecord ? `/lightning/r/Player__c/${this.playerDetail.player.Id}/view` : "";
  }

  get totalPayments() {
    return this.hasPlayerRecord ? this.playerDetail.player.TotalPaymentsRollup__c : 0;
  }

  get balanceDue() {
    return this.hasPlayerRecord ? this.playerDetail.player.BalanceDueFormula__c : 0;
  }

  get paymentRows() {
    return this.draftPayments.map((row) => ({
      index: row.index,
      payment: row.payment,
      isEditing: row.rowMode === "edit",
      isRowActionDisabled: this.editingPaymentIndex !== null && this.editingPaymentIndex !== row.index,
      canDelete: !!row.payment.Id
    }));
  }

  get hasPayments() {
    return this.paymentRows.length > 0;
  }

  get isAddPaymentDisabled() {
    return this.isEditOrNew || this.editingPaymentIndex !== null || !this.hasPlayerRecord;
  }

  handleFieldChange(event) {
    const field = event.currentTarget.dataset.field;
    const value = field === "IsActive" ? event.detail.checked : event.detail.value;
    this.draftUsr = { ...this.draftUsr, [field]: value };
  }

  handleEditClick() {
    this.dispatchEvent(new CustomEvent("edit"));
  }

  handleSaveClick() {
    this.dispatchEvent(new CustomEvent("save", { detail: { usr: this.draftUsr } }));
  }

  handleCancelClick() {
    if (!this.confirmDiscardIfDirty()) {
      return;
    }
    this.dispatchEvent(new CustomEvent("cancel"));
  }

  handleCloseClick() {
    if (!this.confirmDiscardIfDirty()) {
      return;
    }
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleAddPaymentClick() {
    if (this.isAddPaymentDisabled) {
      return;
    }
    const newIndex = this.draftPayments.length
      ? Math.max(...this.draftPayments.map((row) => row.index)) + 1
      : 0;
    const blankPayment = {
      Player__c: this.hasPlayerRecord ? this.playerDetail.player.Id : null,
      Amount__c: null,
      PaymentDate__c: null
    };
    this.draftPayments = [...this.draftPayments, { index: newIndex, payment: blankPayment, rowMode: "edit" }];
    this.editingPaymentIndex = newIndex;
  }

  handleEditPaymentClick(event) {
    if (this.editingPaymentIndex !== null) {
      return;
    }
    const index = Number(event.currentTarget.dataset.index);
    this.draftPayments = this.draftPayments.map((row) =>
      row.index === index ? { ...row, rowMode: "edit" } : row
    );
    this.editingPaymentIndex = index;
  }

  handlePaymentFieldChange(event) {
    const index = Number(event.currentTarget.dataset.index);
    const field = event.currentTarget.dataset.field;
    const value = event.detail.value;
    this.draftPayments = this.draftPayments.map((row) =>
      row.index === index ? { ...row, payment: { ...row.payment, [field]: value } } : row
    );
  }

  handleSavePaymentClick(event) {
    const index = Number(event.currentTarget.dataset.index);
    const row = this.draftPayments.find((r) => r.index === index);
    if (!row) {
      return;
    }
    this.dispatchEvent(
      new CustomEvent("savepayment", { detail: { payment: row.payment, balanceDue: this.balanceDue } })
    );
  }

  handleDeletePaymentClick(event) {
    const index = Number(event.currentTarget.dataset.index);
    const row = this.draftPayments.find((r) => r.index === index);
    if (!row || !row.payment.Id) {
      return;
    }
    // eslint-disable-next-line no-alert
    const ok = window.confirm("Are you sure you want to delete this payment?");
    if (!ok) {
      return;
    }
    this.dispatchEvent(new CustomEvent("deletepayment", { detail: { paymentId: row.payment.Id } }));
  }

  handleCancelPaymentClick(event) {
    const index = Number(event.currentTarget.dataset.index);
    const row = this.draftPayments.find((r) => r.index === index);
    if (!row) {
      return;
    }
    if (row.payment.Id) {
      const original = ((this.playerDetail && this.playerDetail.payments) || []).find(
        (p) => p.Id === row.payment.Id
      );
      this.draftPayments = this.draftPayments.map((r) =>
        r.index === index ? { ...r, payment: original ? { ...original } : r.payment, rowMode: "view" } : r
      );
    } else {
      this.draftPayments = this.draftPayments.filter((r) => r.index !== index);
    }
    this.editingPaymentIndex = null;
  }
}
