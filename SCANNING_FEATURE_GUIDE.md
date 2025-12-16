# Document Scanning Feature Guide

## Overview

The TUK CU Mass Messaging App now includes a powerful document scanning feature that can automatically extract attendee information from physical attendance sheets. This feature uses advanced OCR (Optical Character Recognition) technology to digitize manual attendance records.

## Features

### 🔍 Smart Text Recognition
- **Name Detection**: Automatically identifies full names (First Last or First Middle Last)
- **Phone Number Extraction**: Recognizes Kenyan phone numbers in multiple formats:
  - `0712345678` (local format)
  - `+254712345678` (international format)
  - `254712345678` (without plus)
- **Location Detection**: Identifies Kenyan counties and regions
- **Confidence Scoring**: Each extracted record gets a confidence score (High/Medium/Low/Very Low)

### 📱 Multiple Input Methods
1. **Camera Scan**: Take a photo directly from the app
2. **Gallery Selection**: Choose existing photos from your device
3. **Batch Processing**: Scan multiple attendance sheets at once

### 🎯 Intelligent Processing
- **Image Enhancement**: Automatically improves image quality for better OCR
- **Duplicate Detection**: Prevents duplicate entries based on phone numbers
- **Data Validation**: Validates phone numbers and name formats
- **Manual Review**: Review and edit extracted data before saving

### 📊 Quality Assurance
- **Confidence Levels**: 
  - **High (80%+)**: Ready to save automatically
  - **Medium (60-79%)**: Minor verification recommended
  - **Low (40-59%)**: Manual review required
  - **Very Low (<40%)**: Significant editing needed

## How to Use

### 1. Access the Scanner
- Open the **Registration** screen
- Tap the **Document Scanner** icon (📄) in the top-right corner
- Or navigate to the scanner from the main menu

### 2. Choose Scan Method
- **📷 Scan with Camera**: Take a new photo of the attendance sheet
- **🖼️ Select from Gallery**: Choose an existing photo
- **📚 Scan Multiple Images**: Process several sheets at once

### 3. Review Results
- View all extracted attendees with confidence scores
- **Green indicators**: High confidence, ready to save
- **Orange indicators**: Medium confidence, review recommended
- **Red indicators**: Low confidence, editing required

### 4. Edit if Needed
- Tap the **Edit** button (✏️) next to any attendee
- Correct names, phone numbers, or locations
- Add notes for future reference
- Edited entries are marked as "Verified"

### 5. Save to Database
- Select attendees to save (high-confidence entries selected by default)
- Choose the service session
- Tap **Save Selected Attendees**
- Saved attendees are immediately available for messaging

## Best Practices for Scanning

### 📄 Document Preparation
- **Clear Writing**: Ensure names and phone numbers are legible
- **Good Lighting**: Use bright, even lighting when taking photos
- **Straight Alignment**: Keep the document flat and straight
- **High Resolution**: Use the highest camera quality available

### 📱 Photo Tips
- **Fill the Frame**: Make the text as large as possible in the photo
- **Avoid Shadows**: Position lighting to minimize shadows
- **Steady Hands**: Use both hands or a tripod for stability
- **Multiple Angles**: If one photo doesn't work well, try different angles

### 📋 Supported Formats
The scanner works best with these attendance sheet formats:

#### Table Format
```
Name                | Phone Number    | Location
John Doe           | 0712345678      | Nairobi
Jane Smith         | +254787654321   | Mombasa
```

#### List Format
```
1. John Doe - 0712345678 - Nairobi
2. Jane Smith - +254787654321 - Mombasa
```

#### Form Format
```
Name: John Doe
Phone: 0712345678
Location: Nairobi

Name: Jane Smith
Phone: +254787654321
Location: Mombasa
```

## Troubleshooting

### Common Issues and Solutions

#### ❌ "No attendees found"
- **Check image quality**: Ensure text is clear and readable
- **Improve lighting**: Retake photo with better lighting
- **Verify format**: Make sure phone numbers are in Kenyan format
- **Try different angle**: Sometimes a different perspective helps

#### ❌ "Low confidence scores"
- **Edit manually**: Use the edit feature to correct extracted data
- **Retake photo**: Try capturing the document again with better conditions
- **Check handwriting**: Ensure handwritten text is legible

#### ❌ "Wrong phone numbers detected"
- **Manual correction**: Edit the phone numbers in the review screen
- **Format check**: Ensure numbers follow Kenyan mobile format (07XXXXXXXX or +2547XXXXXXXX)

#### ❌ "Names not detected properly"
- **Full names**: Ensure both first and last names are written
- **Clear writing**: Make sure names are legible
- **Proper spacing**: Ensure adequate space between names

### Performance Tips

1. **Batch Processing**: For multiple sheets, use the "Scan Multiple Images" option
2. **Pre-processing**: Ensure documents are well-organized before scanning
3. **Review Systematically**: Check high-confidence entries first, then review lower-confidence ones
4. **Save Regularly**: Save processed attendees in batches to avoid data loss

## Technical Details

### Supported Image Formats
- JPEG (.jpg, .jpeg)
- PNG (.png)
- WebP (.webp)

### Phone Number Formats Recognized
- `0712345678` (Safaricom)
- `0722345678` (Safaricom)
- `0733345678` (Airtel)
- `0700345678` (Airtel)
- `+254712345678` (International)
- `254712345678` (Without plus)

### Kenyan Locations Supported
The scanner recognizes all 47 Kenyan counties and major cities:
- Nairobi, Mombasa, Kisumu, Nakuru, Eldoret
- All county names (Kiambu, Machakos, Kajiado, etc.)
- Major towns and cities

### Data Storage
- **Scanned Data**: Temporarily stored for review
- **Verified Data**: Saved to main attendee database
- **Scan History**: Recent scans available for reference
- **Backup**: All data synced to cloud when online

## Privacy and Security

### Data Protection
- **Local Processing**: OCR processing happens on your device
- **Encrypted Storage**: All data encrypted in local database
- **Cloud Sync**: Secure transmission to Firebase when online
- **Access Control**: Only authorized users can access scanning feature

### Best Practices
- **Delete Photos**: Remove original photos after successful scanning
- **Secure Storage**: Keep physical attendance sheets secure
- **Regular Backups**: Ensure cloud sync is enabled for data backup
- **User Training**: Train staff on proper scanning procedures

## Integration with Messaging

### Seamless Workflow
1. **Scan** attendance sheets
2. **Review** and verify extracted data
3. **Save** attendees to current service session
4. **Message** attendees immediately using existing messaging features

### Service Integration
- Scanned attendees are automatically assigned to the current service session
- All existing messaging features work with scanned attendees
- Reports include both manually registered and scanned attendees

## Future Enhancements

### Planned Features
- **Handwriting Recognition**: Improved support for handwritten documents
- **Multi-language Support**: Recognition of names in local languages
- **Batch Export**: Export scanned data to Excel/CSV
- **Template Recognition**: Support for specific attendance sheet templates
- **Offline OCR**: Enhanced offline processing capabilities

### Feedback and Improvements
The scanning feature continuously improves based on usage patterns and feedback. Report any issues or suggestions through the app's feedback system.

---

## Quick Reference

### Keyboard Shortcuts (Desktop)
- `Ctrl + S`: Open scanner
- `Ctrl + R`: Review last scan
- `Ctrl + E`: Edit selected attendee

### Accessibility Features
- **Screen Reader Support**: Full VoiceOver/TalkBack compatibility
- **High Contrast**: Enhanced visibility for low-vision users
- **Large Text**: Scalable text for better readability
- **Voice Commands**: Voice-activated scanning (where supported)

### Support
For technical support or questions about the scanning feature:
- Check the in-app help section
- Contact your system administrator
- Refer to the main user guide for general app usage

---

*This scanning feature is designed to streamline the process of digitizing physical attendance records while maintaining data accuracy and security.*