import 'package:flutter/material.dart';

class ExpenseCalculatorScreen extends StatefulWidget {
  final String chatId;
  final Function(String)? onSendToChat;

  const ExpenseCalculatorScreen({
    Key? key,
    required this.chatId,
    this.onSendToChat,
  }) : super(key: key);

  @override
  State<ExpenseCalculatorScreen> createState() =>
      _ExpenseCalculatorScreenState();
}

class _ExpenseCalculatorScreenState extends State<ExpenseCalculatorScreen> {
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _electricityController = TextEditingController();
  final TextEditingController _waterController = TextEditingController();
  final TextEditingController _internetController = TextEditingController();

  int _numberOfPeople = 2;
  double _totalPerPerson = 0.0;

  @override
  void initState() {
    super.initState();
    _rentController.addListener(_calculateTotal);
    _electricityController.addListener(_calculateTotal);
    _waterController.addListener(_calculateTotal);
    _internetController.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _rentController.dispose();
    _electricityController.dispose();
    _waterController.dispose();
    _internetController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    try {
      final rent = double.tryParse(_rentController.text) ?? 0.0;
      final electricity = double.tryParse(_electricityController.text) ?? 0.0;
      final water = double.tryParse(_waterController.text) ?? 0.0;
      final internet = double.tryParse(_internetController.text) ?? 0.0;

      final total = (rent + electricity + water + internet) / _numberOfPeople;

      setState(() {
        _totalPerPerson = double.parse(total.toStringAsFixed(2));
      });
    } catch (e) {
      setState(() {
        _totalPerPerson = 0.0;
      });
    }
  }

  String _generateFormattedMessage() {
    final rent = double.tryParse(_rentController.text) ?? 0.0;
    final electricity = double.tryParse(_electricityController.text) ?? 0.0;
    final water = double.tryParse(_waterController.text) ?? 0.0;
    final internet = double.tryParse(_internetController.text) ?? 0.0;

    final utilities = electricity + water + internet;
    final formattedUtilities = utilities > 0
        ? utilities.toStringAsFixed(2)
        : '0.00';
    final formattedRent = rent > 0 ? rent.toStringAsFixed(2) : '0.00';

    return '''--- 📊 Desglose de Gastos BiziMatch ---
🏠 Alquiler: ${formattedRent}€
⚡ Suministros: ${formattedUtilities}€
👥 Total personas: $_numberOfPeople
✅ TOTAL POR PERSONA: ${_totalPerPerson.toStringAsFixed(2)}€''';
  }

  void _sendToChat() {
    final message = _generateFormattedMessage();
    if (widget.onSendToChat != null) {
      widget.onSendToChat!(message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desglose enviado al chat'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } else {
      // Si no hay callback, copiar al portapapeles
      final clipboard = widget.onSendToChat;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mensaje preparado: $message'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF2FBF7),
      appBar: AppBar(
        title: Text(
          'Calculadora de Gastos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF10B981),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título introductorio
              Text(
                '💸 Divide los gastos de forma justa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ingresa los gastos mensuales y define entre cuántas personas se dividen',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 24),

              // Inputs de gastos
              _buildExpenseInput(
                controller: _rentController,
                label: 'Alquiler',
                icon: Icons.home,
                placeholder: '0.00',
              ),
              SizedBox(height: 16),
              _buildExpenseInput(
                controller: _electricityController,
                label: 'Electricidad / Gas',
                icon: Icons.lightbulb,
                placeholder: '0.00',
              ),
              SizedBox(height: 16),
              _buildExpenseInput(
                controller: _waterController,
                label: 'Agua',
                icon: Icons.water_drop,
                placeholder: '0.00',
              ),
              SizedBox(height: 16),
              _buildExpenseInput(
                controller: _internetController,
                label: 'Internet / Otros',
                icon: Icons.wifi,
                placeholder: '0.00',
              ),
              SizedBox(height: 24),

              // Selector de número de personas
              Text(
                'Número de personas: $_numberOfPeople',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              Slider(
                value: _numberOfPeople.toDouble(),
                min: 2,
                max: 10,
                divisions: 8,
                onChanged: (value) {
                  setState(() {
                    _numberOfPeople = value.toInt();
                  });
                  _calculateTotal();
                },
                activeColor: Color(0xFF10B981),
                inactiveColor: Color(0xFFD4EEE1),
              ),
              SizedBox(height: 24),

              // Tarjeta de resumen
              _buildTotalCard(),
              SizedBox(height: 32),

              // Botón de envío
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _sendToChat,
                  icon: Icon(Icons.send),
                  label: Text(
                    'Enviar desglose al chat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String placeholder,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        prefixIcon: Icon(icon, color: Color(0xFF10B981)),
        suffixText: '€',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFFD4EEE1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFFD4EEE1), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF10B981), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF10B981),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total por persona',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_totalPerPerson.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '€',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(color: Colors.white30, thickness: 1),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '👥 $_numberOfPeople persona${_numberOfPeople > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '📊 Total: ${((double.tryParse(_rentController.text) ?? 0.0) + (double.tryParse(_electricityController.text) ?? 0.0) + (double.tryParse(_waterController.text) ?? 0.0) + (double.tryParse(_internetController.text) ?? 0.0)).toStringAsFixed(2)}€',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
