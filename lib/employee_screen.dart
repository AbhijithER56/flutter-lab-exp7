import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Employee registration form + live list of employees stored in the
/// Cloud Firestore collection "employees".
class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key, this.collection});

  /// Optional collection override (used by tests with a fake Firestore).
  /// Defaults to FirebaseFirestore.instance.collection("employees").
  final CollectionReference? collection;

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final _formkey = GlobalKey<FormState>();
  final _namecontroller = TextEditingController();
  final _empidcontroller = TextEditingController();
  final _salarycontroller = TextEditingController();

  // Database instance
  late final CollectionReference employees =
      widget.collection ?? FirebaseFirestore.instance.collection("employees");

  String _status = "";
  bool _isError = false;
  bool _saving = false;

  @override
  void dispose() {
    _namecontroller.dispose();
    _empidcontroller.dispose();
    _salarycontroller.dispose();
    super.dispose();
  }

  // CREATE: validate the form, then insert a new document into "employees".
  // Firestore creates the collection automatically on the first add().
  Future<void> _addEmployee() async {
    FocusScope.of(context).unfocus();
    if (!_formkey.currentState!.validate()) {
      setState(() => _status = "");
      return;
    }

    setState(() {
      _saving = true;
      _status = "";
    });

    try {
      await employees.add({
        'name': _namecontroller.text.trim(),
        'empid': int.parse(_empidcontroller.text.trim()),
        'salary': int.parse(_salarycontroller.text.trim()),
      });
      _namecontroller.clear();
      _empidcontroller.clear();
      _salarycontroller.clear();
      _formkey.currentState!.reset();
      if (!mounted) return;
      setState(() {
        _status = "Data Saved Successfully";
        _isError = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = "Firebase error (${e.code}): ${e.message ?? 'unknown'}";
        _isError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = "Failed to save data: $e";
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return "Please enter your name";
    return null;
  }

  String? _validateEmpId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Please enter your Employee ID";
    }
    final id = int.tryParse(value.trim());
    if (id == null || id <= 0) return "Employee ID must be a positive number";
    return null;
  }

  String? _validateSalary(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Please enter your salary";
    }
    final salary = int.tryParse(value.trim());
    if (salary == null || salary < 0) {
      return "Salary must be a valid whole number";
    }
    return null;
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    bool numeric = false,
    TextInputAction action = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: numeric ? TextInputType.number : TextInputType.name,
        textInputAction: action,
        onFieldSubmitted: action == TextInputAction.done
            ? (_) => _addEmployee()
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formkey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildField(
            controller: _namecontroller,
            label: "Enter your Name",
            validator: _validateName,
          ),
          _buildField(
            controller: _empidcontroller,
            label: "Enter your EmpID",
            validator: _validateEmpId,
            numeric: true,
          ),
          _buildField(
            controller: _salarycontroller,
            label: "Enter your Salary",
            validator: _validateSalary,
            numeric: true,
            action: TextInputAction.done,
          ),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: _saving ? null : _addEmployee,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text("Save Details"),
          ),
          const SizedBox(height: 10),
          if (_status.isNotEmpty)
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(color: _isError ? Colors.red : Colors.green),
            ),
        ],
      ),
    );
  }

  // READ: listen to employees.snapshots() so the list updates in real time.
  Widget _buildEmployeeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: employees.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!.docs;
        if (records.isEmpty) {
          return const Center(child: Text("No Employees Found"));
        }
        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            // Read defensively: documents added by hand in the console
            // may be missing a field.
            final employee =
                records[index].data() as Map<String, dynamic>? ?? {};
            return ListTile(
              title: Text("${employee['name'] ?? '(no name)'}"),
              subtitle: Text(
                "EMPID: ${employee['empid'] ?? '-'} "
                "SALARY:${employee['salary'] ?? '-'}",
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: const Text("Employee Application"),
      ),
      body: SafeArea(
        child: Center(
          // Keep the layout readable on tablets / landscape.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    children: [
                      // The form scrolls on its own when space is short
                      // (landscape / keyboard open) so nothing overflows.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.6,
                        ),
                        child: SingleChildScrollView(child: _buildForm()),
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: _buildEmployeeList()),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
