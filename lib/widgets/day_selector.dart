import 'package:flutter/material.dart';

class DaySelecter extends StatelessWidget {

  final String selectedDay;
  final Function(String) onDaySelected;

  const DaySelecter({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final days = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        height: 70,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          itemBuilder: (context, index) {
            String day = days[index];
            return GestureDetector(
              onTap: () => onDaySelected(day),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: day == selectedDay ? Colors.green.shade400 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                      day,
                      style: TextStyle(
                        color: day == selectedDay ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: "NotoSansBold"
                      ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
