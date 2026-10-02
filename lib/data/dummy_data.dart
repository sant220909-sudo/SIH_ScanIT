import 'package:cyber_nova/models/inspection_model.dart';
import 'package:cyber_nova/utils/app_theme.dart';

class DummyData {
  static const String sampleProductImage =
      'https://images.unsplash.com/photo-1508061253366-f7da158b6d46?w=800&q=80';

  static ProductInfo get sampleProductInfo => ProductInfo(
        productName: 'Roasted Almonds',
        manufacturer: 'ABC Foods Pvt. Ltd.',
        address: 'Mumbai, Maharashtra',
        netQuantity: '250 g',
        mrp: '₹350',
        packingDate: '08/2026',
        consumerCare: '1800-XXX-XXXX',
        countryOfOrigin: 'India',
        batchNumber: 'ALM-2026-082',
        unitSalePrice: '₹1.40 / g',
      );

  static List<ExtractedField> get sampleExtractedFields => [
        ExtractedField(
          id: 'product_name',
          fieldName: 'Product Name',
          value: 'Roasted Almonds',
          confidence: 99.2,
        ),
        ExtractedField(
          id: 'manufacturer',
          fieldName: 'Manufacturer / Packer',
          value: 'ABC Foods Pvt. Ltd.',
          confidence: 97.8,
        ),
        ExtractedField(
          id: 'address',
          fieldName: 'Address',
          value: 'Mumbai, Maharashtra',
          confidence: 95.4,
        ),
        ExtractedField(
          id: 'net_quantity',
          fieldName: 'Net Quantity',
          value: '250 g',
          confidence: 98.6,
        ),
        ExtractedField(
          id: 'mrp',
          fieldName: 'MRP',
          value: '₹350',
          confidence: 99.1,
        ),
        ExtractedField(
          id: 'packing_date',
          fieldName: 'Date of Packing',
          value: '08/2026',
          confidence: 82.3,
        ),
        ExtractedField(
          id: 'consumer_care',
          fieldName: 'Consumer Care',
          value: '1800-XXX-XXXX',
          confidence: 96.7,
        ),
        ExtractedField(
          id: 'country',
          fieldName: 'Country of Origin',
          value: 'India',
          confidence: 99.5,
        ),
      ];

  static List<ComplianceCheck> get sampleComplianceChecks => [
        ComplianceCheck(
          id: 'manufacturer_details',
          ruleName: 'Manufacturer / Packer Details',
          description:
              'Complete name and address of manufacturer/packer must be clearly displayed.',
          status: ComplianceStatus.pass,
        ),
        ComplianceCheck(
          id: 'net_quantity',
          ruleName: 'Net Quantity Declaration',
          description:
              'Net quantity in metric system must be declared conspicuously.',
          status: ComplianceStatus.pass,
        ),
        ComplianceCheck(
          id: 'mrp',
          ruleName: 'Maximum Retail Price (MRP)',
          description:
              'MRP inclusive of all taxes must be displayed on the package.',
          status: ComplianceStatus.pass,
        ),
        ComplianceCheck(
          id: 'packing_date',
          ruleName: 'Manufacturing / Packing Date',
          description:
              'Month and year of manufacture/packing must be clearly visible.',
          status: ComplianceStatus.review,
        ),
        ComplianceCheck(
          id: 'consumer_care',
          ruleName: 'Consumer Care Details',
          description:
              'Contact number/email for consumer redressal must be provided.',
          status: ComplianceStatus.pass,
        ),
        ComplianceCheck(
          id: 'mandatory_declaration',
          ruleName: 'Required Declaration / Label Information',
          description:
              'All mandatory declarations including ingredients, allergens, and nutritional information must be present.',
          status: ComplianceStatus.fail,
        ),
      ];

  static List<Violation> get sampleViolations => [
        Violation(
          id: 'v1',
          title: 'Mandatory declaration missing',
          requirement:
              'Required declaration including nutritional information and allergen warnings was not detected on the product label.',
          status: 'NON-COMPLIANT',
          evidenceNote: 'Evidence marked on product image (lower-right area)',
        ),
      ];

  static InspectionModel get sampleInspection => InspectionModel(
        reportId: 'CN-2026-0001',
        inspectionDate: DateTime(2026, 9, 7),
        productImageUrl: sampleProductImage,
        productInfo: sampleProductInfo,
        extractedFields: sampleExtractedFields,
        complianceChecks: sampleComplianceChecks,
        violations: sampleViolations,
        aiAnalysisComplete: true,
        manualVerificationComplete: true,
      );

  static List<RecentReport> get recentReports => [
        RecentReport(
          id: 'r1',
          productName: 'Roasted Almonds',
          status: ComplianceStatus.pass,
          date: DateTime(2026, 9, 7),
        ),
        RecentReport(
          id: 'r2',
          productName: 'Shampoo 200ml',
          status: ComplianceStatus.review,
          date: DateTime(2026, 9, 6),
        ),
        RecentReport(
          id: 'r3',
          productName: 'Biscuits Pack',
          status: ComplianceStatus.fail,
          date: DateTime(2026, 9, 5),
        ),
      ];

  static String formattedDateTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${formattedDate(date)}  $hour:$minute';
  }

  static String formattedDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String formattedDateShort(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }
}
