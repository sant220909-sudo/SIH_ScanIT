from pydantic import BaseModel, Field, ConfigDict
from typing import Any, Literal, Optional


class ExtractedValue(BaseModel):
    model_config = ConfigDict(extra="ignore")

    value: Optional[str] = None
    exact_visible_text: Optional[str] = None
    confidence: float = 0.0
    evidence_description: Optional[str] = None
    source_image_index: Optional[int] = None


class QuantityValue(BaseModel):
    model_config = ConfigDict(extra="ignore")

    value: Optional[float] = None
    unit: Optional[str] = None
    exact_visible_text: Optional[str] = None
    confidence: float = 0.0
    evidence_description: Optional[str] = None
    source_image_index: Optional[int] = None


class MrpValue(BaseModel):
    model_config = ConfigDict(extra="ignore")

    value: Optional[float] = None
    currency: Optional[str] = None
    exact_visible_text: Optional[str] = None
    confidence: float = 0.0
    evidence_description: Optional[str] = None
    source_image_index: Optional[int] = None


class ExtractionResult(BaseModel):
    model_config = ConfigDict(extra="ignore")

    product_name: ExtractedValue = Field(default_factory=ExtractedValue)
    common_name: ExtractedValue = Field(default_factory=ExtractedValue)
    manufacturer: ExtractedValue = Field(default_factory=ExtractedValue)
    packer: ExtractedValue = Field(default_factory=ExtractedValue)
    importer: ExtractedValue = Field(default_factory=ExtractedValue)
    address: ExtractedValue = Field(default_factory=ExtractedValue)
    dimensions_size: ExtractedValue = Field(default_factory=ExtractedValue)
    country_of_origin: ExtractedValue = Field(default_factory=ExtractedValue)
    net_quantity: QuantityValue = Field(default_factory=QuantityValue)
    mrp: MrpValue = Field(default_factory=MrpValue)
    packing_date: ExtractedValue = Field(default_factory=ExtractedValue)
    best_before: ExtractedValue = Field(default_factory=ExtractedValue)
    consumer_care: ExtractedValue = Field(default_factory=ExtractedValue)
    email: ExtractedValue = Field(default_factory=ExtractedValue)
    phone: ExtractedValue = Field(default_factory=ExtractedValue)
    unit_sale_price: ExtractedValue = Field(default_factory=ExtractedValue)
    batch_number: ExtractedValue = Field(default_factory=ExtractedValue)
    language_used: ExtractedValue = Field(default_factory=ExtractedValue)
    language_of_declarations: ExtractedValue = Field(default_factory=ExtractedValue)
    other_declarations: list[str] = Field(default_factory=list)
    overall_confidence: float = 0.0


class ComplianceCheckResult(BaseModel):
    rule_id: str
    rule_reference: str
    field: str
    requirement: str
    status: Literal["PASS", "FAIL", "REVIEW"]
    reason: str
    confidence: float
    severity: str
    mandatory: bool
    exact_visible_text: Optional[str] = None
    evidence_description: Optional[str] = None
    source_image_index: Optional[int] = None
    explanation: Optional[str] = None


class ComplianceSummary(BaseModel):
    passed: int
    failed: int
    review: int


class InspectionResponse(BaseModel):
    inspection_id: str
    extraction: dict[str, Any]
    checks: list[ComplianceCheckResult]
    summary: ComplianceSummary
    overall_status: Literal["COMPLIANT", "NON_COMPLIANT", "MANUAL_REVIEW"]
    disclaimer: str
    prototype_notice: str
