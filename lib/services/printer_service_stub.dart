import 'ticket_data.dart';

Future<void> doInitPrinter() async {}

Future<bool> doTestPrint() async => true;

Future<bool> doPrintTicket({
  required TicketData ticket,
  required List<Map<String, String>> ticketUnits,
}) async =>
    true;