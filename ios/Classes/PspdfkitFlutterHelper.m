//
//  Copyright © 2018-2019 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//
#import "PspdfkitFlutterHelper.h"
#import "PspdfkitFlutterConverter.h"

@implementation PspdfkitFlutterHelper

+ (void)processMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result forViewController:(PSPDFViewController *)pdfViewController {
    if ([@"setFormFieldValue" isEqualToString:call.method]) {
        NSString *value = call.arguments[@"value"];
        NSString *fullyQualifiedName = call.arguments[@"fullyQualifiedName"];
        result([PspdfkitFlutterHelper setFormFieldValue:value forFieldWithFullyQualifiedName:fullyQualifiedName forViewController:pdfViewController]);
    } else if ([@"getFormFieldValue" isEqualToString:call.method]) {
        NSString *fullyQualifiedName = call.arguments[@"fullyQualifiedName"];
        result([PspdfkitFlutterHelper getFormFieldValueForFieldWithFullyQualifiedName:fullyQualifiedName forViewController:pdfViewController]);
    } else if ([@"applyInstantJson" isEqualToString:call.method]) {
        NSString *annotationsJson = call.arguments[@"annotationsJson"];
        if (annotationsJson.length == 0) {
            result([FlutterError errorWithCode:@"" message:@"annotationsJson may not be nil or empty." details:nil]);
            return;
        }
        PSPDFDocument *document = pdfViewController.document;
        if (!document || !document.isValid) {
            result([FlutterError errorWithCode:@"" message:@"PDF document not found or is invalid." details:nil]);
            return;
        }
        PSPDFDataContainerProvider *jsonContainer = [[PSPDFDataContainerProvider alloc] initWithData:[annotationsJson dataUsingEncoding:NSUTF8StringEncoding]];
        NSError *error;
        BOOL success = [document applyInstantJSONFromDataProvider:jsonContainer toDocumentProvider:document.documentProviders.firstObject lenient:NO error:&error];
        if (!success) {
            result([FlutterError errorWithCode:@"" message:@"Error while importing document Instant JSON." details:nil]);
        } else {
            [pdfViewController reloadData];
            result(@(YES));
        }
    } else if ([@"exportInstantJson" isEqualToString:call.method]) {
        PSPDFDocument *document = pdfViewController.document;
        if (!document || !document.isValid) {
            result([FlutterError errorWithCode:@"" message:@"PDF document not found or is invalid." details:nil]);
            return;
        }
        NSError *error;
        NSData *data = [document generateInstantJSONFromDocumentProvider:document.documentProviders.firstObject error:&error];
        NSString *annotationsJson = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        if (annotationsJson == nil) {
            result([FlutterError errorWithCode:@"" message:@"Error while exporting document Instant JSON." details:error.localizedDescription]);
        } else {
            result(annotationsJson);
        }
    } else if ([@"addAnnotation" isEqualToString:call.method]) {
        id jsonAnnotation = call.arguments[@"jsonAnnotation"];
        result([PspdfkitFlutterHelper addAnnotation:jsonAnnotation forViewController:pdfViewController]);
    } else if ([@"removeAnnotation" isEqualToString:call.method]) {
        id jsonAnnotation = call.arguments[@"jsonAnnotation"];
        result([PspdfkitFlutterHelper removeAnnotation:jsonAnnotation forViewController:pdfViewController]);
    } else if ([@"getAnnotations" isEqualToString:call.method]) {
        PSPDFPageIndex pageIndex = [call.arguments[@"pageIndex"] longLongValue];
        NSString *typeString = call.arguments[@"type"];
        result([PspdfkitFlutterHelper getAnnotationsForPageIndex:pageIndex andType:typeString forViewController:pdfViewController]);
    } else if ([@"getAllUnsavedAnnotations" isEqualToString:call.method]) {
        result([PspdfkitFlutterHelper getAllUnsavedAnnotationsForViewController:pdfViewController]);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

# pragma mark - Document Helpers

+ (PSPDFDocument *)documentFromPath:(NSString *)path {
    NSURL *url;

    if ([path hasPrefix:@"/"]) {
        url = [NSURL fileURLWithPath:path];
    } else {
        url = [NSBundle.mainBundle URLForResource:path withExtension:nil];
    }

    if ([PspdfkitFlutterHelper isImageDocument:path]) {
        return [[PSPDFImageDocument alloc] initWithImageURL:url];
    } else {
        return [[PSPDFDocument alloc] initWithURL:url];
    }
}

+ (BOOL)isImageDocument:(NSString *)path {
    NSString *fileExtension = path.pathExtension.lowercaseString;
    return [fileExtension isEqualToString:@"png"] || [fileExtension isEqualToString:@"jpeg"] || [fileExtension isEqualToString:@"jpg"];
}

# pragma mark - Password Helper

+ (void)unlockWithPasswordIfNeeded:(PSPDFDocument *)document dictionary:(NSDictionary *)dictionary {
    if ((id)dictionary == NSNull.null || !dictionary || dictionary.count == 0) {
        return;
    }
    NSString *password = dictionary[@"password"];
    if (password.length) {
        [document unlockWithPassword:password];
    }
}

# pragma mark - Toolbar Customization

+ (void)setToolbarTitle:(NSString *)toolbarTitle forViewController:(PSPDFViewController *)pdfViewController {
    // Early return if the toolbar title is not explicitly set in the configuration dictionary.
    if (!toolbarTitle) {
        return;
    }

    // We allow setting a null title.
    pdfViewController.title = (id)toolbarTitle == NSNull.null ? nil : toolbarTitle;
}

+ (void)setLeftBarButtonItems:(nullable NSArray <NSString *> *)items forViewController:(PSPDFViewController *)pdfViewController {
    if ((id)items == NSNull.null || !items || items.count == 0) {
        return;
    }
    NSMutableArray *leftItems = [NSMutableArray array];
    for (NSString *barButtonItemString in items) {
        UIBarButtonItem *barButtonItem = [self barButtonItemFromString:barButtonItemString forViewController:pdfViewController];
        if (barButtonItem && ![pdfViewController.navigationItem.rightBarButtonItems containsObject:barButtonItem]) {
            [leftItems addObject:barButtonItem];
        }
    }

    [pdfViewController.navigationItem setLeftBarButtonItems:[leftItems copy] animated:NO];
}

+ (void)setRightBarButtonItems:(nullable NSArray <NSString *> *)items forViewController:(PSPDFViewController *)pdfViewController {
    if ((id)items == NSNull.null || !items || items.count == 0) {
        return;
    }
    NSMutableArray *rightItems = [NSMutableArray array];
    for (NSString *barButtonItemString in items) {
        UIBarButtonItem *barButtonItem = [PspdfkitFlutterHelper barButtonItemFromString:barButtonItemString forViewController:pdfViewController];
        if (barButtonItem && ![pdfViewController.navigationItem.leftBarButtonItems containsObject:barButtonItem]) {
            [rightItems addObject:barButtonItem];
        }
    }

    [pdfViewController.navigationItem setRightBarButtonItems:[rightItems copy] animated:NO];
}

+ (UIBarButtonItem *)barButtonItemFromString:(NSString *)barButtonItem forViewController:(PSPDFViewController *)pdfViewController {
    if ([barButtonItem isEqualToString:@"closeButtonItem"]) {
        return pdfViewController.closeButtonItem;
    } else if ([barButtonItem isEqualToString:@"outlineButtonItem"]) {
        return pdfViewController.outlineButtonItem;
    } else if ([barButtonItem isEqualToString:@"searchButtonItem"]) {
        return pdfViewController.searchButtonItem;
    } else if ([barButtonItem isEqualToString:@"thumbnailsButtonItem"]) {
        return pdfViewController.thumbnailsButtonItem;
    } else if ([barButtonItem isEqualToString:@"documentEditorButtonItem"]) {
        return pdfViewController.documentEditorButtonItem;
    } else if ([barButtonItem isEqualToString:@"printButtonItem"]) {
        return pdfViewController.printButtonItem;
    } else if ([barButtonItem isEqualToString:@"openInButtonItem"]) {
        return pdfViewController.openInButtonItem;
    } else if ([barButtonItem isEqualToString:@"emailButtonItem"]) {
        return pdfViewController.emailButtonItem;
    } else if ([barButtonItem isEqualToString:@"messageButtonItem"]) {
        return pdfViewController.messageButtonItem;
    } else if ([barButtonItem isEqualToString:@"annotationButtonItem"]) {
        return pdfViewController.annotationButtonItem;
    } else if ([barButtonItem isEqualToString:@"bookmarkButtonItem"]) {
        return pdfViewController.bookmarkButtonItem;
    } else if ([barButtonItem isEqualToString:@"brightnessButtonItem"]) {
        return pdfViewController.brightnessButtonItem;
    } else if ([barButtonItem isEqualToString:@"activityButtonItem"]) {
        return pdfViewController.activityButtonItem;
    } else if ([barButtonItem isEqualToString:@"settingsButtonItem"]) {
        return pdfViewController.settingsButtonItem;
    } else {
        return nil;
    }
}

# pragma mark - Forms

+ (id)setFormFieldValue:(NSString *)value forFieldWithFullyQualifiedName:(NSString *)fullyQualifiedName forViewController:(PSPDFViewController *)pdfViewController {
    PSPDFDocument *document = pdfViewController.document;

    if (!document || !document.isValid) {
        FlutterError *error = [FlutterError errorWithCode:@"" message:@"PDF document not found or is invalid." details:nil];
        return error;
    }

    if (fullyQualifiedName == nil || fullyQualifiedName.length == 0) {
        FlutterError *error = [FlutterError errorWithCode:@"" message:@"Fully qualified name may not be nil or empty." details:nil];
        return error;
    }

    BOOL success = NO;
    for (PSPDFFormElement *formElement in document.formParser.forms) {
        if ([formElement.fullyQualifiedFieldName isEqualToString:fullyQualifiedName]) {
            if ([formElement isKindOfClass:PSPDFButtonFormElement.class]) {
                if ([value isEqualToString:@"selected"]) {
                    [(PSPDFButtonFormElement *)formElement select];
                    success = YES;
                } else if ([value isEqualToString:@"deselected"]) {
                    [(PSPDFButtonFormElement *)formElement deselect];
                    success = YES;
                }
            } else if ([formElement isKindOfClass:PSPDFChoiceFormElement.class]) {
                ((PSPDFChoiceFormElement *)formElement).selectedIndices = [NSIndexSet indexSetWithIndex:value.integerValue];
                success = YES;
            } else if ([formElement isKindOfClass:PSPDFTextFieldFormElement.class]) {
                formElement.contents = value;
                success = YES;
            } else if ([formElement isKindOfClass:PSPDFSignatureFormElement.class]) {
                FlutterError *error = [FlutterError errorWithCode:@"" message:@"Signature form elements are not supported." details:nil];
                return error;
            } else {
                return @(NO);
            }
            break;
        }
    }

    if (!success) {
        FlutterError *error = [FlutterError errorWithCode:@"" message:[NSString stringWithFormat:@"Error while searching for a form element with name %@.", fullyQualifiedName] details:nil];
        return error;
    }

    return @(YES);
}

+ (id)getFormFieldValueForFieldWithFullyQualifiedName:(NSString *)fullyQualifiedName forViewController:(PSPDFViewController *)pdfViewController {
    if (fullyQualifiedName == nil || fullyQualifiedName.length == 0) {
        FlutterError *error = [FlutterError errorWithCode:@"" message:@"Fully qualified name may not be nil or empty." details:nil];
        return error;
    }

    PSPDFDocument *document = pdfViewController.document;
    id formFieldValue = nil;
    for (PSPDFFormElement *formElement in document.formParser.forms) {
        if ([formElement.fullyQualifiedFieldName isEqualToString:fullyQualifiedName]) {
            formFieldValue = formElement.value;
            break;
        }
    }

    if (formFieldValue == nil) {
        FlutterError *error = [FlutterError errorWithCode:@"" message:[NSString stringWithFormat:@"Error while searching for a form element with name %@.", fullyQualifiedName] details:nil];
        return error;
    }

    return formFieldValue;
}

# pragma mark - Instant JSON

+ (id)addAnnotation:(id)jsonAnnotation forViewController:(PSPDFViewController *)pdfViewController {
    PSPDFDocument *document = pdfViewController.document;
    if (!document || !document.isValid) {
        return [FlutterError errorWithCode:@"" message:@"PDF document not found or is invalid." details:nil];
    }

    NSData *data;
    if ([jsonAnnotation isKindOfClass:NSString.class]) {
        data = [jsonAnnotation dataUsingEncoding:NSUTF8StringEncoding];
    } else if ([jsonAnnotation isKindOfClass:NSDictionary.class])  {
        data = [NSJSONSerialization dataWithJSONObject:jsonAnnotation options:0 error:nil];
    }

    if (data == nil) {
        return [FlutterError errorWithCode:@"" message:@"Invalid JSON Annotation." details:nil];
    }

    PSPDFDocumentProvider *documentProvider = document.documentProviders.firstObject;
    PSPDFAnnotation *annotation = [PSPDFAnnotation annotationFromInstantJSON:data documentProvider:documentProvider error:NULL];
    BOOL success = [document addAnnotations:@[annotation] options:nil];

    if (!success) {
        return [FlutterError errorWithCode:@"" message:@"Failed to add annotation." details:nil];
    }

    return @(YES);
}

+ (id)removeAnnotation:(id)jsonAnnotation forViewController:(PSPDFViewController *)pdfViewController {
    PSPDFDocument *document = pdfViewController.document;
    if (!document || !document.isValid) {
        return [FlutterError errorWithCode:@"" message:@"PDF document not found or is invalid." details:nil];
    }

    NSString *annotationUUID;
    if ([jsonAnnotation isKindOfClass:NSString.class]) {
        NSData *jsonData = [jsonAnnotation dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:nil];
        if (jsonDict) { annotationUUID = jsonDict[@"uuid"]; }
    } else if ([jsonAnnotation isKindOfClass:NSDictionary.class])  {
        if (jsonAnnotation) { annotationUUID = jsonAnnotation[@"uuid"]; }
    }

    if (annotationUUID.length <= 0) {
        return [FlutterError errorWithCode:@"" message:@"Invalid annotation UUID." details:nil];
    }

    BOOL success = NO;
    NSArray<PSPDFAnnotation *> *allAnnotations = [[document allAnnotationsOfType:PSPDFAnnotationTypeAll].allValues valueForKeyPath:@"@unionOfArrays.self"];
    for (PSPDFAnnotation *annotation in allAnnotations) {
        // Remove the annotation if the uuids match.
        if ([annotation.uuid isEqualToString:annotationUUID]) {
            success = [document removeAnnotations:@[annotation] options:nil];
            break;
        }
    }

    return @(success);
}

+ (id)getAnnotationsForPageIndex:(PSPDFPageIndex)pageIndex andType:(NSString *)typeString forViewController:(PSPDFViewController *)pdfViewController {
    PSPDFDocument *document = pdfViewController.document;
    if (!document || !document.isValid) {
        return [FlutterError errorWithCode:@"" message:@"PDF document not found or is invalid." details:nil];
    }

    PSPDFAnnotationType type = [PspdfkitFlutterConverter annotationTypeFromString:typeString];

    NSArray <PSPDFAnnotation *> *annotations = [document annotationsForPageAtIndex:pageIndex type:type];
    NSArray <NSDictionary *> *annotationsJSON = [PspdfkitFlutterConverter instantJSONFromAnnotations:annotations];

    if (annotationsJSON) {
        return annotationsJSON;
    } else {
        return [FlutterError errorWithCode:@"" message:@"Failed to get annotations." details:nil];
    }
}

+ (id)getAllUnsavedAnnotationsForViewController:(PSPDFViewController *)pdfViewController {
    PSPDFDocument *document = pdfViewController.document;
    if (!document || !document.isValid) {
        return [FlutterError errorWithCode:@"" message:@"PDF document not found or is invalid." details:nil];
    }

    PSPDFDocumentProvider *documentProvider = document.documentProviders.firstObject;
    NSData *data = [document generateInstantJSONFromDocumentProvider:documentProvider error:NULL];
    NSDictionary *annotationsJSON = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:NULL];

    if (annotationsJSON) {
        return annotationsJSON;
    }  else {
        return [FlutterError errorWithCode:@"" message:@"Failed to get annotations." details:nil];
    }
}

@end
